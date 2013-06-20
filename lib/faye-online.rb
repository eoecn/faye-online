# encoding: UTF-8

require 'yaml'
require 'thin'
require 'json'
require 'rails'
require 'active_record'
require 'activerecord_idnamecache'
require 'redis'
require "faye"
require 'faye/redis'

(proc do
Faye::WebSocket.load_adapter('thin')
# Faye::WebSocket.load_adapter('rainbows')
if ENV['DEBUG_FAYE']
  Faye::Logging.log_level = :debug
  require 'logger'
  _logger = Logger.new("log/faye.log")
  Faye.logger = lambda {|m| _logger.info m }
end

# connect to database
database_yml = ENV['database_yml'] || File.join(ENV['RAILS_PATH'] || `pwd`.strip, 'config/database.yml')
ActiveRecord::Base.establish_connection YAML.load_file(database_yml).inject({}) {|h, kv| h[kv[0].to_sym] = kv[1]; h }[:production]
end).call

class FayeOnline
  cattr_accessor :engine_proxy, :redis

  ValidChannel = proc {|channel| !!channel.to_s.match(/\A[0-9a-z\/]+\Z/i) } # 只支持数字字母和斜杠
  MONITORED_CHANNELS = ['/meta/connect', '/meta/disconnect'] # '/meta/subscribe', '/connect', '/close' are ignored
  LOCAL_IP = Socket.ip_address_list.detect{|intf| intf.ipv4_private?}.ip_address # http://stackoverflow.com/questions/5029427/ruby-get-local-ip-nix
  LOCAL_FAYE_URI = URI.parse("http://#{LOCAL_IP}:#{ENV['FAYE_PORT'] || 9292}/faye")
  cattr_accessor :redis_opts, :faye_client, :valid_message_proc

  def initialize redis_opts, valid_message_proc = nil

    raise "Please run `$faye_server = FayeOnline.get_server` first, cause we have to bind disconnect event." if not $faye_server.is_a?(Faye::RackAdapter)
    FayeOnline.redis_opts = redis_opts
    FayeOnline.valid_message_proc = valid_message_proc || (proc {|message| true })
    FayeOnline.redis = Redis.new(FayeOnline.redis_opts)
    FayeOnline.redis.select FayeOnline.redis_opts[:database]

    FayeOnline.faye_client ||= Faye::Client.new(LOCAL_FAYE_URI)

    # 配置ActiveRecord
    if Rails.root.nil?
      Dir[File.expand_path('../../app/models/*.rb', __FILE__)].each {|f| require f }
    end

    return self
  end

  def incoming(message, callback)
    Message.new(message).process
    callback.call(message)
  end

  def self.channel_clientIds_array
    array = []
    FayeOnline.redis.keys("/#{FayeOnline.redis_opts[:namespace]}/uid_to_clientIds*").sort.each do |k|
      _data = FayeOnline.redis.hgetall(k).values.map {|i| JSON.parse(i) rescue i }.flatten
      array << [k, _data]
    end
    array
  end
  def self.uniq_clientIds
    self.channel_clientIds_array.map(&:last).flatten.uniq
  end

  def self.disconnect clientId
    message = {'channel' => '/meta/disconnect', 'clientId' => clientId}

    # fake a client to disconnect, 仅仅接受message.auth为空，即网络失去连接的情况
    FayeOnline::Message.new(message.merge('fake' => 'true')).process if not message['auth']
  end

end


def FayeOnline.get_server redis_opts, valid_message_proc = nil
  $faye_server = Faye::RackAdapter.new(
    :mount   => '/faye',

    # the maximum time to hold a connection open before returning the response. This is given in seconds and must be smaller than the timeout on your frontend webserver(thin). Faye uses Thin as its webserver, whose default timeout is 30 seconds.
    # https://groups.google.com/forum/?fromgroups#!topic/faye-users/DvFrPGOinKw
    :timeout => 60,

    :engine  => redis_opts.merge(:type  => Faye::Redis),
    :ping => 30 # (optional) how often, in seconds, to send keep-alive ping messages over WebSocket and EventSource connections. Use this if your Faye server will be accessed through a proxy that kills idle connections.
  )

  $faye_server.bind(:handshake) do |clientId|
  end
  $faye_server.bind(:subscribe) do |clientId, channel|
  end
  $faye_server.bind(:unsubscribe) do |clientId, channel|
  end
  $faye_server.bind(:publish) do |clientId, channel, data|
  end
  $faye_server.bind(:disconnect) do |clientId|
    # TODO ping client
    # [https://groups.google.com/forum/#!searchin/faye-users/disconnect/faye-users/2bn8xUHF5-E/A4a3Sk7RgW4J] It's expected. The browser will not always be able to deliver an explicit disconnect message, which is why there is server-side idle client detection.
    FayeOnline.disconnect clientId

    # dynamic compute interval seconds
    tmp = FayeOnline.channel_clientIds_array.reject {|i| i[1].blank? }
    puts "开始有 #{FayeOnline.uniq_clientIds.count}个"
    tmp.map(&:last).flatten.uniq.shuffle[0..19].each do |_clientId|
      if not FayeOnline.engine_proxy.has_connection? _clientId
        puts "开始处理无效 #{_clientId}"
        # 1. 先伪装去disconnect clientId
        # 2. 如果失败，就直接操作redis修改
        if not FayeOnline.disconnect(_clientId)
          # 没删除成功，因为之前没有设置auth
          k = (tmp.detect {|a, b| b.index(_clientId) } || [])[0]
          # 直接从redis清除无效_clientId
          FayeOnline.redis.hgetall(k).each do |k2, v2|
            v3 = JSON.parse(v2) rescue []
            v3.delete _clientId
            FayeOnline.redis.hset(k, k2, v3.to_json)
          end if k
        end
      end
    end
    puts "结束有 #{FayeOnline.uniq_clientIds.count}个"
  end

  $faye_server.add_extension FayeOnline.new(redis_opts, valid_message_proc)

  FayeOnline.engine_proxy = $faye_server.instance_variable_get("@server").engine

  return $faye_server
end

require File.expand_path("../faye-online/message.rb", __FILE__)
require File.expand_path("../faye-online/rails_engine.rb", __FILE__)
