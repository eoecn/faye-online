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
configure it,
```ruby
@server = Faye::RackAdapter.new
@server.add_extension FayeOnline.new(Faye_redis_opts)
```
and start faye server
```zsh
bundle exec rake faye:start
```

4.  faye client
```javascript
var client = new Faye.Client(faye_url)
var AuthExtension = {
  outgoing: function (message, callback) {
    message.auth = (message.auth || {});
    _.extend(message.auth, {
      room_channel: eoe.class_channel,
      time_channel: eoe.lesson_channel,
      current_user: {
        uid: 470700,
        uname: 'mvj3',
        other: 'what ever'
      }
    });

    callback(message);
  }
};
client.addExtension(AuthExtension);
```



Tech
-------------------------------------------
用户离开房间的两种情况:
1. 关闭所有相关页面。client端主动触发disconnect发消息。
2. 网络掉线。server端ping定时检测。


清理失去网络连接的clientIds:
1. TODO
