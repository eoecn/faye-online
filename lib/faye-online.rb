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
  cattr_accessor :engine_proxy, :redis, :faye_uri

  ValidChannel = proc {|channel| !!channel.to_s.match(/\A[0-9a-z\/]+\Z/i) } # 只支持数字字母和斜杠
  MONITORED_CHANNELS = ['/meta/connect', '/meta/disconnect'] # '/meta/subscribe', '/connect', '/close' are ignored
  LOCAL_IP = Socket.ip_address_list.detect{|intf| intf.ipv4_private?}.ip_address # http://stackoverflow.com/questions/5029427/ruby-get-local-ip-nix
  cattr_accessor :redis_opts, :faye_client, :valid_message_proc

  def initialize redis_opts, valid_message_proc = nil
    raise "faye_port it not configed in redis_opts, cause other app need to read FayeOnline.faye_uri variable for connecting" if redis_opts[:faye_port].nil?
    FayeOnline.faye_uri = URI.parse("http://#{LOCAL_IP}:#{redis_opts[:faye_port]}/faye")

    raise "Please run `$faye_server = FayeOnline.get_server` first, cause we have to bind disconnect event." if not $faye_server.is_a?(Faye::RackAdapter)
    FayeOnline.redis_opts = redis_opts
    FayeOnline.valid_message_proc = valid_message_proc || (proc {|message| true })
    FayeOnline.redis = Redis.new(FayeOnline.redis_opts)
    FayeOnline.redis.select FayeOnline.redis_opts[:database]

    FayeOnline.faye_client ||= Faye::Client.new(FayeOnline.faye_uri.to_s)

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


require File.expand_path("../faye-online/message.rb", __FILE__)
require File.expand_path("../faye-online/rails_engine.rb", __FILE__)
require File.expand_path("../faye-online/status.rb", __FILE__)
require File.expand_path("../faye-online/server.rb", __FILE__)
