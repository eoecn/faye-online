# encoding: UTF-8

class FayeUserOnlineTime < ActiveRecord::Base
  attr_accessible :user_id, :online_times
  TIME2013 = Time.parse("20130101")
  TimeFormat = "%Y%m%d%H%M%S"

  def spend_time channel_name; @channel_name = channel_name; data[spend_key] end
  def start_time channel_name; @channel_name = channel_name; data[start_key] end

  # 只有两种状态，不管一个用户有多少个连接
  # 1, 没开始: 设置started_at为当前值
  # 2, 关闭所有连接: 去除started_at，更新spended
  # 再添加一个连接: 在调用接口方实现
  def start? channel_name
    @channel_name = channel_name
    !!data[start_key]
  end
  def start channel_name
    @channel_name = channel_name
    data[start_key] = Time.now.strftime(TimeFormat)
    resave!
  end
  def start_key; "#{@channel_name}_started_at"; end
  def spend_key; "#{@channel_name}_spended"; end

  def spend_time_in_realtime channel_name
    _old_spend_time = self.spend_time(channel_name).to_i

    # 计时为0。 用户打开多个浏览器，在完成课时时其他页面没有关掉，导致faye_online_time不能关闭计时，所以无法计算spend_time
    _new_spend_time = 0
    if _start_time = self.start_time(channel_name)
      # 兼容 没访问页面前  计时的start_time还没有开始
      _new_spend_time = _start_time.blank? ? 0 : (Time.now - Time.parse(_start_time))
    end

    (_old_spend_time + _new_spend_time).round(0)
  end

  def stop channel_name
    @channel_name = channel_name
    if data[start_key]
      data[spend_key] ||= 0
      data[spend_key] += (Time.now - Time.parse(data[start_key])).to_i
      data.delete start_key
      resave!
    end
  end

  def data
    @data ||= (JSON.parse(online_time.online_times) rescue {})
  end
  def resave!
    online_time.update_attributes! :online_times => data.to_json
  end

  def online_time; self end
  def uid; self.user_id; end

end
