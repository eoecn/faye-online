# encoding: UTF-8
# faye.ru example

load File.expand_path('../lib/faye-online.rb', __FILE__)

# 配置redis
ENV['RAILS_PATH'] ||= `pwd`.strip
Faye_redis_opts = YAML.load_file(File.join(File.join(ENV['RAILS_PATH'], 'config/faye_redis.yml'))).inject({}) {|h, kv| h[kv[0].to_sym] = kv[1]; h }


@server = Faye::RackAdapter.new(
  :mount   => '/faye',
  :timeout => 42,
  :engine  => Faye_redis_opts.merge(:type  => Faye::Redis),
)

@server.bind(:handshake) do |client_id|
end
@server.bind(:subscribe) do |client_id, channel|
end
@server.bind(:unsubscribe) do |client_id, channel|
end
@server.bind(:publish) do |client_id, channel, data|
end
@server.bind(:disconnect) do |client_id|
end

@server.add_extension FayeOnline.new(Faye_redis_opts)
run @server
