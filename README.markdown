Faye Online user list and time count
===========================================

Usage
-------------------------------------------
1.  Add it to Gemfile

```ruby
gem 'faye-online'
```

2. add faye related table

```zsh
bundle exec rake db:migrate
```

3.  faye server
Create a faye.ru at your rails app root, configure it,

```ruby
$faye_server = FayeOnline.get_server {:host=>"localhost", :port=>6379, :database=>1, :namespace=>"faye", :gc=>5}
run $faye_server
```

and start faye server

```sh
bundle exec rake faye:start
DEBUG_FAYE=true DEBUG=true bundle exec rackup faye.ru -s thin -E production -p 9292
```

4.  faye client

```js
eoe.faye = Faye.init_online_client({
  faye_url: faye_url,
  client_opts: {},
  auth_opts: {
    room_channel: eoe.class_channel,
    time_channel: eoe.lesson_channel,
    current_user: eoe.current_user
  }
});
```

Tech
-------------------------------------------
用户离开房间的两种情况:

1. 关闭所有相关页面。client端主动触发disconnect发消息。
2. 网络掉线。server端ping定时检测。

清理失去网络连接的clientIds:

TODO
-------------------------------------------
1. 管理后台
2. 封装持久化数据写入，存储包括做生产用的Redis和测试用的内存。抽象FayeOnline.redis，以避免覆写全局
3. Cluster front end https://github.com/alexkazeko/faye_shards
4. use rainbows server, see faye-websocket README。一些尝试见rainbows.conf, https://groups.google.com/forum/#!msg/faye-users/cMPhvIpk-OU/MgRcFhmz8koJ
5. js输出room_channel和time_channel等信息


Related Resources
-------------------------------------------
1. https://github.com/ryanb/private_pub Private Pub is a Ruby gem for use with Rails to publish and subscribe to messages through Faye. It allows you to easily provide real-time updates through an open socket without tying up a Rails process. All channels are private so users can only listen to events you subscribe them to.

2. http://blog.edweng.com/2012/06/02/faye-extensions-tracking-users-in-a-chat-room/ only track clientId

3. http://faye.jcoglan.com/ruby/monitoring.html  tech detail about track connect and disconnect in faye
