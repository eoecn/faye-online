# encoding: UTF-8

def FayeOnline.faye_online_status
  array = []
  clientIds = Set.new
  channel_clientIds_array = FayeOnline.channel_clientIds_array

  clientId_to_users = channel_clientIds_array.map(&:last).flatten.uniq.inject({}) do |h, _clientId|
    _data = JSON.parse(Redis.current.get("/#{FayeOnline.redis_opts[:namespace]}/clientId_auth/#{_clientId}")) rescue {}
    h[_clientId] = (_data['current_user'] || {}).except('uhash').values
    h
  end

  channel_clientIds_array.each do |_channel, _clientIds|
    _a = _clientIds.map {|i| [i, clientId_to_users[i]] }
    _c = _a.map {|i| i[1][0] }.uniq.count
    array << "#{_channel}: #{_c}个用户:  #{_a}"
    _clientIds.each {|i| clientIds.add i }
  end

  array.unshift ""
  users = clientIds.map {|i| clientId_to_users[i] }.uniq {|i| i[0] }
  array.unshift "/classes/[0-9]+ 用于班级讨论的消息通讯, /courses/[0-9]+/lessons/[0-9]+ 用于课时的计时"
  array.unshift ""
  array.unshift "#{users.count}个用户分别是: #{users}"
  array.unshift ""
  array.unshift "实时在线clientIds总共有#{clientIds.count}个: #{clientIds.to_a}"
  array.unshift ""
  array.unshift "一个clientId表示用户打开了一个页面。一个用户在同一课时可能打开多个页面，那就是一个user，多个clientId"

  # 删除意外没有退出的在线用户列表
  uids = users.map(&:first)
  FayeChannelOnlineList.all.reject {|i| i.data.blank? }.each do |online_list|
    online_list.user_list.each do |uid|
      online_list.delete uid if not uids.include? uid
    end
  end

  array
end
