class AddDeviceIds < ActiveRecord::Migration[6.1]
  def change
    add_column :wk_spent_fors, :device_id, :string, limit: 100
    add_column :wk_attendances, :device_id, :string, limit: 100
    add_column :wk_crm_activities, :device_id, :string, limit: 100
  end
end
