# encoding: UTF-8

require 'rake'

namespace :faye do
  desc "Start faye server"
  task :start => :environment do
    # Rack::Builder.new.run @server # TODO 脱离父进程
    # Rack::Server.start
    #
    # 自动启动faye服务器
    # from http://stackoverflow.com/questions/6430437/autorun-the-faye-server-when-i-start-the-rails-server
    @faye_ru = File.join(`bundle show faye-online`.strip, 'faye.ru')
    Thread.new do
      # system("bundle exec rackup faye.ru -s thin -E production")
      system("bundle exec rackup #{@faye_ru} -s thin -E production")
    end
  end

end
