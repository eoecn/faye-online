# encoding: UTF-8

def FayeOnline.get_server redis_opts, valid_message_proc = nil
  $faye_server = Faye::RackAdapter.new(
    :mount   => '/faye',

    # the maximum time to hold a connection open before returning the response. This is given in seconds and must be smaller than the timeout on your frontend webserver(thin). Faye uses Thin as its webserver, whose default timeout is 30 seconds.
    # https://groups.google.com/forum/?fromgroups#!topic/faye-users/DvFrPGOinKw
    :timeout => 10,

    # [https://groups.google.com/forum/#!searchin/faye-users/disconnect/faye-users/2bn8xUHF5-E/A4a3Sk7RgW4J] It's expected. The browser will not always be able to deliver an explicit disconnect message, which is why there is server-side idle client detection.
    # garbag collect disconnected clientIds in EventMachine.add_periodic_timer
    :engine  => {:gc => 60}.merge(redis_opts.merge(:type  => Faye::Redis)),

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
    FayeOnline.disconnect clientId

    # dynamic compute interval seconds
    tmp = FayeOnline.channel_clientIds_array.reject {|i| i[1].blank? }
    # delete below, cause map data is valid
    if tmp.any?
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
  end

  $faye_server.add_extension FayeOnline.new(redis_opts, valid_message_proc)

  FayeOnline.engine_proxy = $faye_server.instance_variable_get("@server").engine

  return $faye_server
end
