class CreateWkMaterialEntrySn < ActiveRecord::Migration[5.2]
  def change
    create_table :wk_material_entry_sns do |t|
      t.references :material_entry, class: "WkMaterialEntry", null: false
      t.string :serial_number
      t.timestamps null: false
    end
    add_column :wk_inventory_items, :running_sn, :string
  end
end