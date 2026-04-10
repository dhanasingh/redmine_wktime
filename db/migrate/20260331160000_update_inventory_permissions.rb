class UpdateInventoryPermissions < ActiveRecord::Migration[7.2]
  def up
    add_column :wk_permissions, :plugin, :string, limit: 5, default: 'wk', null: false
    WkPermission.where(short_name: ["S_SHIFT", "E_SHIFT"]).update_all(modules: "Scheduling")
    execute <<-SQL
      UPDATE wk_permissions SET name = 'BASIC INVENTORY PRIVILEGE', short_name = 'B_INV_PRVLG', modules = 'Inventory' WHERE short_name = 'V_INV';
      UPDATE wk_permissions SET name = 'ADMIN INVENTORY PRIVILEGE', short_name = 'A_INV_PRVLG', modules = 'Inventory' WHERE short_name = 'D_INV';
    SQL
  end

  def down
    remove_column :wk_permissions, :plugin
    WkPermission.where(short_name: ["S_SHIFT", "E_SHIFT"]).update_all(modules: "Shift Scheduling")
    execute <<-SQL
      UPDATE wk_permissions SET name = 'VIEW INVENTORY', short_name = 'V_INV', modules = 'Inventory' WHERE short_name = 'B_INV_PRVLG';
      UPDATE wk_permissions SET name = 'DELETE INVENTORY', short_name = 'D_INV', modules = 'Inventory' WHERE short_name = 'A_INV_PRVLG';
    SQL
  end
end