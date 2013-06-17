class AddFayeUserLoginLogs < ActiveRecord::Migration
  def up
    create_table :faye_user_login_logs, :options => 'ENGINE=Innodb DEFAULT CHARSET=utf8', :id => false do |t|
      t.integer  :status, :limit => 2
      t.integer  :uid
      t.datetime :t
      t.integer  :channel_id
      t.string   :clientId
    end
    add_index :faye_user_login_logs, [:t, :channel_id, :uid], :name => 'idx_all'
  end

  def down
  end
end
