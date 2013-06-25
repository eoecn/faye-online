# encoding: UTF-8

module FayeOnline_Rails
  class Engine < Rails::Engine
    initializer "faye_online_rails.load_app_instance_data" do |app|
      app.class.configure do
        ['db/migrate', 'app/assets', 'app/models', 'app/controllers', 'app/views'].each do |path|
          config.paths[path] ||= []
          config.paths[path] += QA_Rails::Engine.paths[path].existent
        end
      end
    end
    initializer "faye_online_rails.load_static_assets" do |app|
      app.middleware.use ::ActionDispatch::Static, "#{root}/public"
    end
    rake_tasks do
      load File.expand_path('../../../Rakefile', __FILE__)
    end
  end
end
