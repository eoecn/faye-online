# encoding: UTF-8

require 'thin'
require 'json'
require 'rails'
require 'active_record'
require 'activerecord_idnamecache'
require 'redis'
require "faye"
require 'faye/redis'

Faye::WebSocket.load_adapter('thin')
if ENV['DEBUG_FAYE']
  Faye::Logging.log_level = :debug
  require 'logger'
  _logger = Logger.new("log/faye.log")
  Faye.logger = lambda {|m| _logger.info m }
end

class FayeOnline
  cattr_accessor :engine_proxy

  ValidChannel = proc {|channel| !!channel.to_s.match(/\A[0-9a-z\/]+\Z/i) } # 只支持数字字母和斜杠
  MONITORED_CHANNELS = ['/meta/connect', '/meta/disconnect'] # '/meta/subscribe', '/connect', '/close' are ignored
  LOCAL_IP = Socket.ip_address_list.detect{|intf| intf.ipv4_private?}.ip_address # http://stackoverflow.com/questions/5029427/ruby-get-local-ip-nix
  LOCAL_FAYE_URI = URI.parse("http://#{LOCAL_IP}:#{ENV['FAYE_PORT'] || 9292}/faye")
  cattr_accessor :redis_opts, :faye_client, :valid_message_proc

  def initialize redis_opts, valid_message_proc = nil
    FayeOnline.redis_opts = redis_opts
    FayeOnline.valid_message_proc = valid_message_proc || (proc {|message| true })
    Redis.current = Redis.new(FayeOnline.redis_opts)
    Redis.current.select FayeOnline.redis_opts[:database]

    FayeOnline.faye_client ||= Faye::Client.new(LOCAL_FAYE_URI.to_s)

    # 配置ActiveRecord
    if Rails.root.nil?
      ActiveRecord::Base.establish_connection YAML.load_file(File.join(ENV['RAILS_PATH'], 'config/database.yml')).inject({}) {|h, kv| h[kv[0].to_sym] = kv[1]; h }[:production]
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
    Redis.current.keys("/#{FayeOnline.redis_opts[:namespace]}/uid_to_clientIds*").sort.each do |k|
      _data = Redis.current.hgetall(k).values.map {|i| JSON.parse(i) rescue i }.flatten
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
    FayeOnline::Message.new(message).process if not message['auth']
  end

end

require File.expand_path("../faye-online/message.rb", __FILE__)
require File.expand_path("../faye-online/rails_engine.rb", __FILE__)
