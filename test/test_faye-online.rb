# encoding: UTF-8

ENV['database_yml'] = File.expand_path('../database.yml', __FILE__)

require 'test/unit'
require 'pry-debugger'
require 'faye-online'

class TestFayeOnline < Test::Unit::TestCase
  def setup
    # setup  database
    Dir['db/migrate/*'].map {|i| eval File.read(i).gsub(/ENGINE=(MyISAM|Innodb) DEFAULT CHARSET=utf8/i, "") } # support sqlite
    # migrate
    FayeCreateUserList.new.change
    AddFayeUserLoginLogs.new.up

    # setup redis & faye server
    redis_opts = {:host=>"localhost", :port=>6379, :database=>1, :namespace=>"faye"}
    $faye_server = FayeOnline.get_server redis_opts

  end

  def test_init
  end

end
