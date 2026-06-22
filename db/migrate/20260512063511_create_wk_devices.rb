class CreateWkDevices < ActiveRecord::Migration[7.2]
  def up
    unless table_exists?(:wk_devices)
      create_table :wk_devices do |t|
        t.integer :user_id, null: false
        t.string :device_id, limit: 100, null: false
        t.integer :status, default: 0 # 0: Pending, 1: Approved, 2: Rejected
        t.string :brand
        t.string :model
        t.string :os_version
        t.string :app_version
        t.datetime :last_login_at
        t.timestamps
      end
      add_index :wk_devices, [:user_id, :device_id], unique: true
    end

    unless WkPermission.where(short_name: 'A_DEVICE').exists?
      WkPermission.create(
        name: "MANAGE DEVICES",
        short_name: "A_DEVICE",
        modules: "Devices",
        created_at: Time.current,
        updated_at: Time.current
      )
    end
  end

  def down
    WkPermission.where(short_name: 'A_DEVICE').destroy_all
    drop_table :wk_devices if table_exists?(:wk_devices)
  end
end
