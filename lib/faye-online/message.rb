# encoding: UTF-8

# 管理用户在线文档
# 一个用户在单个房间单个多个页面，就有了多个clientId。
# 1. 用户在线状态规则
# 在线: 超过一个clientId
# 离线: 零个clientId
# 2. 清理过期clientId，以防止存储在redis Hashes里的数组无法删除个别元素。因为怀疑为过期clientId之后就没有连接，所以也不会进行任何操作。
# 采用策略是放到一个clientId和开始时间对应的redis Hashes里，在用户'/meta/disconnect'时检测各个clientId有效性

class FayeOnline
  # To allow multiple messages process in their own Message instance.
  class Message

    attr_accessor :message
    def initialize _msg
      self.message = _msg
      self.current_channel # load message.auth
      self
    end

    # 数据: {"channel"=>"/meta/disconnect", "clientId"=>"sqq4oxlwhj84zw92n0e592j8iq989yy", "id"=>"7", "auth"=>{"room_channel"=>"/classes/4", "time_channel"=>"/courses/5/lessons/1", "current_user"=>{"uid"=>470700, "uname"=>"mvj3"}}}
    def process
      @time_begin = Time.now

      # 主动检测是否离开，以减少GC的消耗
      # TODO re-implement autodisonnect, pull request to faye.gem
      if message['channel'] == "/faye_online/before_leave"
        EM.run do
          EM.add_timer(3) do
            FayeOnline.disconnect(current_clientId) if not FayeOnline.engine_proxy.has_connection?(current_clientId)
          end
        end
        return false;
      end

      # 验证是否用FayeOnline处理
      step_idx = MONITORED_CHANNELS.index(message['channel'])
      return false if step_idx.nil?

      # 验证配置参数是否正确
      return false if !(message['auth'] && (room_channel && time_channel && current_user))
      raise "#{current_user.inspect} is invalid, the correct data struct is, .e.g. {uid: 470700, uname: 'mvj3'}" if !(current_user["uid"] && current_user["uname"])

      # 验证渠道名字是否合法
      (puts "invalid channel => #{message.inspect}" if ENV['DEBUG']; return false) if !(ValidChannel.call(message['auth']['room_channel']) && ValidChannel.call(message['auth']['time_channel']))
      # 验证message是否合法
      (puts "invalid message => #{message.inspect}" if ENV['DEBUG']; return false) if not FayeOnline.valid_message_proc.call(message)

      begin
        case step_idx

        # A. 处理*开启*一个客户端
        when 0
          ### 处理 room_channel 在线人数
          # *开始1* add 当前用户的clientIds数组
          current_user_in_current_room__clientIds.add(current_clientId)
          online_list.add current_user['uid']

          ### 处理 time_chanel 在线时长
          current_user_in_current_time__clientIds.add(current_clientId)
          online_time.start time_channel if not online_time.start? time_channel
          logger_online_info "连上"

          # 绑定用户数据到clientId，以供服务器在主动disconnect时使用

        # B. 处理*关闭*一个客户端(，但是这个用户可能还有其他客户端在连着)
        when 1
          # 解除 因意外原因导致的 clientId 没有过期
          current_user_current_clientIds.each do |_clientId|
            str = if FayeOnline.engine_proxy.has_connection?(_clientId)
              "clientId[#{_clientId}] 还有连接"
            else
              [current_user_current_clientIds_arrays, current_user_in_current_time__clientIds].each {|a| a.delete _clientId }
              "clientId[#{_clientId}] 没有连接的无效 已被删除"
            end
            puts str if ENV['DEBUG']
          end
          puts if ENV['DEBUG']

          ### 处理 room_channel 在线人数
          # *开始2* delete 当前用户的clientIds数组
          current_user_in_current_room__clientIds.delete(current_clientId)
          online_list.delete current_user['uid'] if current_user_in_current_room__clientIds.blank? # 一个uid的全部clientId都退出了

          ### 处理 time_chanel 在线时长
          # 关闭定时在线时间
          current_user_in_current_time__clientIds.delete(current_clientId)
          online_time.stop time_channel if current_user_in_current_time__clientIds.size.zero?
          logger_online_info "离开"
        end

      rescue => e # 确保每次都正常存储current_user_in_current_room__clientIds
        puts [e, e.backtrace].flatten.join("\n")
      end

      # *结束* save 当前用户的clientIds数组
      FayeOnline.redis.hset redis_key__room, current_user['uid'], current_user_in_current_room__clientIds.to_json
      FayeOnline.redis.hset redis_key__time, current_user['uid'], current_user_in_current_time__clientIds.to_json

      # 发布在线用户列表
      FayeOnline.faye_client.publish("#{room_channel}/user_list", {'count' => online_list.user_count, 'user_list' => online_list.user_list}) if FayeOnline.faye_client

      puts "本次处理处理时间 #{((Time.now - @time_begin) * 1000).round(2)}ms" if ENV['DEBUG']
      puts message.inspect
      puts
      return true
    end

    def logger_online_info status
      _t = online_time.start_time(time_channel)
      _start_time_str_ = _t ? Time.parse(_t).strftime("%Y-%m-%d %H:%M:%S") : nil
      puts "*#{status}* 用户#{current_user['uname']}[#{current_user['uid']}] 的clientId #{current_clientId}。"
      puts "当前用户在 #{redis_key__room} 的clientIds列表为 #{current_user_in_current_room__clientIds.inspect}。在线用户有#{online_list.user_list.count}个，他们是 #{online_list.user_list.inspect}"
      puts "当前用户在 #{redis_key__time} 的clientIds列表为 #{current_user_in_current_time__clientIds.inspect}。开始时间为#{_start_time_str_}, 渡过时间为 #{online_time.spend_time(time_channel) || '空'}。"

      # 记录用户登陆登出情况，方便之后追踪
      _s = {"连上" => 1, "离开" => 0}[status]
      # 用可以过期的Redis键值对来检测单个clientId上次是否为 "连上" 或 "离开"
      _k = "/#{FayeOnline.redis_opts[:namespace]}/clientId_status/#{current_clientId}"
      _s_old = FayeOnline.redis.get(_k).to_s
      # *连上*和*离开* 只能操作一次
      if _s_old.blank? || # 没登陆的
        (_s.to_s != _s_old) # 已登陆的

        # 把不*连上*和*离开*把放一张表，写时不阻塞
        FayeUserLoginLog.create! :channel_id => FayeChannel[time_channel], :uid => current_user['uid'], :t => DateTime.now, :status => _s, :clientId => current_clientId

        FayeOnline.redis.multi do
          FayeOnline.redis.set(_k, _s)
          FayeOnline.redis.expire(_k, 2.weeks)
        end
      end
    end
    def online_list; FayeChannelOnlineList.find_or_create_by_channel_id(FayeChannel[room_channel]) end
    def online_time; FayeUserOnlineTime.find_or_create_by_user_id(current_user['uid']) end

    # 渠道信息
    def current_channel
      # 从clientId反设置auth信息，并只设置一次
      if message['auth'] && !message['_is_auth_load']
        FayeOnline.redis.multi do
          FayeOnline.redis.set(redis_key__auth, message['auth'].to_json)
          FayeOnline.redis.expire(redis_key__auth, 2.weeks)
        end
        message['_is_auth_load'] = true
      else
        message['auth'] ||= JSON.parse(FayeOnline.redis.get(redis_key__auth)) rescue {}
      end
      message['channel']
    end
    def time_channel; message['auth']['time_channel'] end
    def room_channel; message['auth']['room_channel'] end

    # 用户信息
    def current_user; message['auth']['current_user'] end
    def current_clientId; message['clientId'] end

    # room和time 分别对应 clientId 的关系
    def current_user_in_current_room__clientIds
      @_current_user_in_current_room__clientIds ||= begin
        _a = JSON.parse(FayeOnline.redis.hget(redis_key__room, current_user['uid'])) rescue []
        Set.new(_a)
      end
    end
    def current_user_in_current_time__clientIds
      @_current_user_in_current_time__clientIds ||= begin
        _a = JSON.parse(FayeOnline.redis.hget(redis_key__time, current_user['uid'])) rescue []
        Set.new(_a)
      end
    end
    def redis_key__room; "/#{FayeOnline.redis_opts[:namespace]}/uid_to_clientIds#{room_channel}" end
    def redis_key__time; "/#{FayeOnline.redis_opts[:namespace]}/uid_to_clientIds#{time_channel}" end
    def redis_key__auth; "/#{FayeOnline.redis_opts[:namespace]}/clientId_auth/#{current_clientId}" end
    def current_user_current_clientIds_arrays
      [current_user_in_current_room__clientIds, current_user_in_current_time__clientIds]
    end
    def current_user_current_clientIds
      current_user_current_clientIds_arrays.map(&:to_a).flatten.uniq
    end

  end

end
