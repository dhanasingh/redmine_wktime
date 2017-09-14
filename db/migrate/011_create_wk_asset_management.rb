class CreateWkAssetManagement < ActiveRecord::Migration

	def change
	
		add_column :wk_products, :depreciation_rate, :integer
		add_reference :wk_products, :ledger, :class => "wk_ledgers", :null => true, index: true
		
		add_column :wk_inventory_items, :is_loggable, :boolean, :default => true
		# add_column :wk_inventory_items, :rental_price, :float
		
		create_table :wk_asset_properties do |t|
			t.references :inventory_item, :class => "wk_inventory_items", :index => true
			t.string :name
			t.float :rate
			t.string :rate_per, :limit => 3
			t.boolean :is_disposed
			t.float :disposed_rate
			t.float :current_value
			t.timestamps null: false
		end
		
		create_table :wk_asset_depreciation do |t|
			t.references :inventory_item, :class => "wk_inventory_items", :index => true
			t.date :depreciation_date
			t.float :acutual_amount
			t.float :depreciation_amount
			t.timestamps null: false
		end
		
	end
end