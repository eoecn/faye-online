# encoding: UTF-8

def FayeOnline.status
  array = []
  clientIds = Set.new
  channel_clientIds_array = FayeOnline.channel_clientIds_array

  clientId_to_users = channel_clientIds_array.map(&:last).flatten.uniq.inject({}) do |h, _clientId|
    _data = JSON.parse(FayeOnline.redis.get("/#{FayeOnline.redis_opts[:namespace]}/clientId_auth/#{_clientId}")) rescue {}
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


def FayeOnline.log params, user_name_proc = proc {|uid| uid }
  scope = FayeUserLoginLog.order("t ASC")

  # 个人整理后列出
  if params[:user]
    scope = scope.where(:uid => user_name_proc.call(params[:user]))

    channel_to_logs = scope.inject({}) {|h, log| i = FayeChannel[log.channel_id]; h[i] ||= []; h[i] << log; h }

    array = ["用户 #{params[:user]}[#{user_name_proc.call(params[:user])}] 的登陆日志详情"]
    channel_to_logs.each do |channel, logs|
      array << ''
      array << channel
      logs2 = logs.inject({}) {|h, log| h[log.clientId] ||= []; h[log.clientId] << log; h }

      # 合并交叉的时间
      ctc = CrossTimeCalculation.new
      logs2.each do |clientId, _logs|
        # logs = logs.sort {|a, b| (a && a.t) <=> (b && b.t) }
        if _logs.size > 0
          # binding.pry if _logs[1].nil?
          te = _logs[1] ? _logs[1].t : nil
          ctc.add(_logs[0].t, te)
          _time_passed = CrossTimeCalculation.new.add(_logs[0].t, te).total_seconds.to_i
        end
        array << [clientId, _logs.map {|_log| "#{_log.status}:  #{_log.t.strftime("%Y-%m-%d %H:%M:%S")}" }, "#{_time_passed || '未知'}秒"].flatten.compact.inspect
      end
      array << "共用时 #{ctc.total_seconds.to_i}秒"
    end
    array
  # 群体直接列出日志
  else
    scope.limit(500).map do |log|
      [%w[离开 连上][log.status], log.uid, user_name_proc.call(log.uid), log.t.strftime("%Y-%m-%d %H:%M:%S"), FayeChannel[log.channel_id], log.clientId].inspect
    end
  end
end
