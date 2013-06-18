# encoding: UTF-8

require 'test/unit'
require 'faye-online'

class TestFayeOnline < Test::Unit::TestCase
  def setup
    @redis_opts = {:host=>"localhost", :port=>6379, :database=>1, :namespace=>"faye"}
    $faye_server = FayeOnline.get_server @redis_opts
  end

  def test_init
  end

end
