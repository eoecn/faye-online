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

术语表
-------------------------------------------
### 用户上线
有很多个clientId连到server。其中可能多个clientId关联的是一个user，这个在 Faye.init_online_client 可以配置。

### 用户离线
一个user关联的所有clientId失去连接后才算离线。
server判断一个user离开房间的两种机制:
1. client端主动触发disconnect发消息，对于的实际操作是关闭所有相关页面。
2. 网络掉线。在 `FayeOnline.get_server` 设置gc参数让server端定时ping所有的clientId，具体方法是 `FayeOnline.engine_proxy.has_connection? clientId`。如果检测是失去连接，那么server就给自己发个伪装的disconnect消息。 清理失去网络连接的clientIds:



TODO
-------------------------------------------
1. 管理后台
3. Cluster front end https://github.com/alexkazeko/faye_shards
4. use rainbows server, see faye-websocket README。一些尝试见rainbows.conf, https://groups.google.com/forum/#!msg/faye-users/cMPhvIpk-OU/MgRcFhmz8koJ
5. js输出room_channel和time_channel等信息



Related Resources
-------------------------------------------
1. https://github.com/ryanb/private_pub Private Pub is a Ruby gem for use with Rails to publish and subscribe to messages through Faye. It allows you to easily provide real-time updates through an open socket without tying up a Rails process. All channels are private so users can only listen to events you subscribe them to.

2. http://blog.edweng.com/2012/06/02/faye-extensions-tracking-users-in-a-chat-room/ only track clientId

3. http://faye.jcoglan.com/ruby/monitoring.html  tech detail about track connect and disconnect in faye
