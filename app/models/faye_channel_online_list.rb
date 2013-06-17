# encoding: UTF-8

class FayeChannelOnlineList < ActiveRecord::Base
  attr_accessible :channel_id, :user_info_list

  def add uid
    uid = uid.to_i; return if uid.zero?
    online_list.update_attributes! :user_info_list => online_list.data.add(uid).to_json
  end

  def delete uid
    uid = uid.to_i; return if uid.zero?
    online_list.update_attributes! :user_info_list => online_list.data.delete(uid).to_json
  end

  def data
    @data ||= begin
      _a = JSON.parse(online_list.user_info_list) rescue []
      Set.new(_a)
    end
  end

  def user_list; online_list.data end
  def user_count; online_list.data.count end

  def online_list; self end
end
