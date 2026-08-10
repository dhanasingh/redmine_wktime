class AddAutoApproveDeviceToWkUsers < ActiveRecord::Migration[7.2]
  def up
    unless column_exists?(:wk_users, :auto_approve_device)
      add_column :wk_users, :auto_approve_device, :boolean, default: false, null: false
    end
    unless column_exists?(:wk_users, :allow_multi_device)
      add_column :wk_users, :allow_multi_device, :boolean, default: false, null: false
    end
  end

  def down
    remove_column :wk_users, :allow_multi_device if column_exists?(:wk_users, :allow_multi_device)
    remove_column :wk_users, :auto_approve_device if column_exists?(:wk_users, :auto_approve_device)
  end
end
