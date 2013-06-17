# encoding: UTF-8

module FayeOnline_Rails
  class Engine < Rails::Engine
    initializer "faye_online_rails.load_app_instance_data" do |app|
      app.class.configure do
        # Pull in all the migrations from FayeOnline_Rails to the application
        config.paths['db/migrate'] += FayeOnline_Rails::Engine.paths['db/migrate'].existent
        config.paths['app/models'] += FayeOnline_Rails::Engine.paths['app/models'].existent
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
