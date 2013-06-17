class FayeCreateUserList < ActiveRecord::Migration
  def change
    create_table :faye_channels, :options => 'ENGINE=MyISAM DEFAULT CHARSET=utf8' do |t|
      t.string     :name
      t.timestamps
    end
    add_index :faye_channels, [:name], :unique => true

    create_table :faye_channel_online_lists, :options => 'ENGINE=Innodb DEFAULT CHARSET=utf8' do |t|
      t.integer  :channel_id, :default => 0
      t.text     :user_info_list
      t.integer  :lock_version, :default => 0
      t.timestamps
    end
    add_index :faye_channel_online_lists, [:channel_id]

    create_table :faye_user_online_times, :options => 'ENGINE=Innodb DEFAULT CHARSET=utf8' do |t|
      t.integer  :user_id, :default => 0
      t.text     :online_times
      t.integer  :lock_version, :default => 0
      t.timestamps
    end
    add_index :faye_user_online_times, [:user_id], :unique => true

  end
end
