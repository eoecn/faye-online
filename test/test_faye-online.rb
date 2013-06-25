# encoding: UTF-8

ENV['database_yml'] = File.expand_path('../database.yml', __FILE__)

require 'test/unit'
require 'pry-debugger'
require 'active_support/core_ext'

require 'faye-online'
require 'fake_redis'


class TestFayeOnline < Test::Unit::TestCase
  def setup
    # setup  database
    Dir['db/migrate/*'].map {|i| eval File.read(i).gsub(/ENGINE=(MyISAM|Innodb) DEFAULT CHARSET=utf8/i, "") } # support sqlite
    # migrate
    FayeCreateUserList.new.change
    AddFayeUserLoginLogs.new.up

    # setup redis & faye server
    redis_opts = {:host=>"localhost", :port=>50000, :database=>1, :namespace=>"faye"}
    $faye_server = FayeOnline.get_server redis_opts

    @message1 = {"channel"=>"/meta/disconnect", "clientId"=>"sqq4oxlwhj84zw92n0e592j8iq989yy", "id"=>"7", "auth"=>{"room_channel"=>"/classes/4", "time_channel"=>"/courses/5/lessons/1", "current_user"=>{"uid"=>470700, "uname"=>"mvj3"}}}
    FayeOnline.faye_client = nil # dont publish from server to client
  end

  def test_validate_message
    msg = @message1.dup
    msg['auth']['current_user'].delete 'uid'
    assert_raise RuntimeError do
      FayeOnline::Message.new(msg).process
    end

    msg = @message1.dup
    msg['auth'].delete('room_channel')
    assert_not_equal FayeOnline::Message.new(msg).process, true
  end

end
