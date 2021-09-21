class CreateWkMaterialEntrySn < ActiveRecord::Migration[5.2]
  def up
		if !ActiveRecord::Base.connection.table_exists? "wk_material_entry_sns"
			create_table :wk_material_entry_sns do |t|
				t.references :material_entry, class: "WkMaterialEntry", null: false
				t.string :serial_number
				t.timestamps null: false
			end
			add_column :wk_inventory_items, :running_sn, :string
		else
			execute <<-SQL
				delete from schema_migrations where version='2021040821101330-redmine_wktime';
			SQL
		end
  end
  
  def down
    remove_column :wk_inventory_items, :running_sn
    drop_table :wk_material_entry_sns
  end
end