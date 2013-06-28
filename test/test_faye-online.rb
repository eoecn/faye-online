# encoding: UTF-8

ENV['database_yml'] = File.expand_path('../database.yml', __FILE__)

require 'test/unit'
require 'pry-debugger'
require 'active_support/core_ext'

require 'faye-online'
require 'fake_redis'


class TestFayeOnline < Test::Unit::TestCase
  # setup  database
  Dir['db/migrate/*'].map {|i| eval File.read(i).gsub(/ENGINE=(MyISAM|Innodb) DEFAULT CHARSET=utf8/i, "") } # support sqlite
  # migrate
  FayeCreateUserList.new.change
  AddFayeUserLoginLogs.new.up

  # setup redis & faye server
  redis_opts = {:host=>"localhost", :port=>50000, :database=>1, :namespace=>"faye", :faye_port => 9292}
  $faye_server = FayeOnline.get_server redis_opts
  FayeOnline.faye_client = nil # dont publish from server to client

  def setup
    @message_connect = {"channel"=>"/meta/connect", "clientId"=>"sqq4oxlwhj84zw92n0e592j8iq989yy", "id"=>"7", "auth"=>{"room_channel"=>"/classes/4", "time_channel"=>"/courses/5/lessons/1", "current_user"=>{"uid"=>470700, "uname"=>"mvj3"}}}
    @message_connect_1 = {"channel"=>"/meta/connect", "clientId"=>"qqq4oxlwhj84zw92n0e592j8iq989yy", "id"=>"8", "auth"=>{"room_channel"=>"/classes/4", "time_channel"=>"/courses/5/lessons/1", "current_user"=>{"uid"=>1, "uname"=>"admin"}}}
    @message_connect_2 = {"channel"=>"/meta/connect", "clientId"=>"pqq4oxlwhj84zw92n0e592j8iq989yy", "id"=>"9", "auth"=>{"room_channel"=>"/classes/4", "time_channel"=>"/courses/5/lessons/1", "current_user"=>{"uid"=>2, "uname"=>"iceskysl"}}}

    @room_channel_id = FayeChannel[@message_connect['auth']['room_channel']]
  end

  def test_validate_message
    msg = @message_connect.dup
    msg['auth']['current_user'].delete 'uid'
    assert_raise RuntimeError do
      FayeOnline::Message.new(msg).process
    end

    msg = @message_connect.dup
    msg['auth'].delete('room_channel')
    assert_not_equal FayeOnline::Message.new(msg).process, true
  end

  def test_one_user
    # login
    FayeOnline::Message.new(@message_connect).process
    assert_equal FayeOnline.channel_clientIds_array.flatten.count("sqq4oxlwhj84zw92n0e592j8iq989yy"), 2, "Login clientId should have two `sqq4oxlwhj84zw92n0e592j8iq989yy`"

    # relogin the same clientId
    FayeOnline::Message.new(@message_connect).process
    assert_equal FayeOnline.channel_clientIds_array.flatten.count("sqq4oxlwhj84zw92n0e592j8iq989yy"), 2, "Login clientId should have two `sqq4oxlwhj84zw92n0e592j8iq989yy`"
    assert_equal FayeUserLoginLog.where(:clientId => "sqq4oxlwhj84zw92n0e592j8iq989yy").count, 1, "Login at second time, but there should only one log"

    assert_equal FayeChannelOnlineList.where(:channel_id => @room_channel_id).first.user_list, Set.new([470700]), "There should be only 470700 user"

    # logout
    msg = @message_connect.dup
    msg["channel"] = "/meta/disconnect"
    FayeOnline::Message.new(msg).process
    assert_equal FayeOnline.channel_clientIds_array.flatten.count("sqq4oxlwhj84zw92n0e592j8iq989yy"), 0, "Login clientId should have none `sqq4oxlwhj84zw92n0e592j8iq989yy`"
    assert_equal FayeUserLoginLog.where(:clientId => "sqq4oxlwhj84zw92n0e592j8iq989yy").count, 2, "Login twice, but there should only two log"

    FayeUserLoginLog.delete_all
  end

  def test_more_user
    # login id#1, id#470700
    [@message_connect, @message_connect_1].each {|msg| FayeOnline::Message.new(msg).process }
    assert_equal FayeUserLoginLog.where(:clientId => [@message_connect['clientId'], @message_connect_1['clientId']]).count, 2, "Two user login, and there should have two logs"
    assert_equal FayeChannelOnlineList.where(:channel_id => @room_channel_id).first.user_list, Set.new([1, 470700]), "There should be two user"

    # logout id#1
    FayeOnline::Message.new(@message_connect_1.merge("channel" => "/meta/disconnect")).process
    assert_equal FayeUserLoginLog.where(:clientId => [@message_connect['clientId'], @message_connect_1['clientId']]).count, 3, "two user logins, one of them logout, and there should have three logs"
    assert_equal FayeChannelOnlineList.where(:channel_id => @room_channel_id).first.user_list, Set.new([470700]), "There should be one user"

    # login id#1, id#2
    [@message_connect_1, @message_connect_2].each {|msg| FayeOnline::Message.new(msg).process }
    assert_equal FayeUserLoginLog.where(:clientId => [@message_connect['clientId'], @message_connect_1['clientId'], @message_connect_2['clientId']]).count, 5, "five logs"
    assert_equal FayeChannelOnlineList.where(:channel_id => @room_channel_id).first.user_list, Set.new([1, 2, 470700]), "There should be three user"

    # logout id#470700
    FayeOnline::Message.new(@message_connect.merge("channel" => "/meta/disconnect")).process
    assert_equal FayeUserLoginLog.where(:clientId => [@message_connect['clientId'], @message_connect_1['clientId'], @message_connect_2['clientId']]).count, 6, "six logs"
    assert_equal FayeChannelOnlineList.where(:channel_id => @room_channel_id).first.user_list, Set.new([1, 2]), "There should be two user"

    # logout id#1, #id2
    FayeOnline::Message.new(@message_connect_1.merge("channel" => "/meta/disconnect")).process
    FayeOnline::Message.new(@message_connect_2.merge("channel" => "/meta/disconnect")).process
    assert_equal FayeUserLoginLog.where(:clientId => [@message_connect['clientId'], @message_connect_1['clientId'], @message_connect_2['clientId']]).count, 8, "eight logs"
    assert_equal FayeChannelOnlineList.where(:channel_id => @room_channel_id).first.user_list, Set.new, "There should be none user"

    FayeUserLoginLog.delete_all
  end

  def test_online_time
    channel_name = 'test'
    online_time = FayeUserOnlineTime.find_or_create_by_user_id(@message_connect['auth']['current_user']['uid'])
    assert_equal online_time.start?(channel_name), false

    online_time.start channel_name
    assert_equal online_time.start?(channel_name), true
    sleep 1
    online_time.stop channel_name
    assert_equal online_time.spend_time_in_realtime(channel_name).zero?, false
    assert_equal online_time.spend_time(channel_name).zero?, false
  end

end
