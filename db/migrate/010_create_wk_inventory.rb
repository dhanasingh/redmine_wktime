class CreateWkInventory < ActiveRecord::Migration[4.2]

	def change
	
		create_table :wk_product_categories do |t|
			t.string :name
			t.string :description
			t.timestamps null: false
		end
		add_reference :wk_product_categories, :parent, :class => "wk_product_categories", :index => true
		
		create_table :wk_mesure_units do |t|
			t.string :name
			t.string :short_desc
			t.timestamps null: false
		end	
		
		create_table :wk_brands do |t|
			t.string :name
			t.string :description
			t.timestamps null: false
		end
		
		create_table :wk_product_attributes do |t|
			t.string :name
			t.string :description
			t.references :group, :class => "wk_attribute_groups", :null => false, :index => true
			t.timestamps null: false
		end
		
		create_table :wk_attribute_groups do |t|
			t.string :name
			t.string :description
			t.timestamps null: false
		end
		
		# create_table :wk_group_attributes do |t|
			# t.references :attribute, :class => "wk_product_attributes", :null => false, :index => true
			# t.references :group, :class => "wk_attribute_groups", :null => false, :index => true
			# t.timestamps null: false
		# end
		
		create_table :wk_products do |t|
			t.string :name
			t.string :description
			t.string :product_type, :limit => 3
			t.references :category, :class => "wk_product_categories", :null => false, :index => true
			t.references :uom, :class => "wk_mesure_units", :null => false, :index => true
			t.references :created_by_user, :class => "User"
			t.references :modified_by_user, :class => "User"
			t.references :attribute_group, :class => "wk_group_attributes", :null => false, :index => true
			t.timestamps null: false
		end
		
		create_table :wk_product_models do |t|
			t.string :name
			t.string :description
			t.references :product, :class => "wk_products", :null => false, :index => true
			t.references :brand, :class => "wk_brands", :null => false, :index => true
			t.timestamps null: false
		end
		
		create_table :wk_brand_products do |t|
			t.references :product, :class => "wk_products", :null => false, :index => true
			t.references :brand, :class => "wk_brands", :null => false, :index => true
			t.timestamps null: false
		end
		
		create_table :wk_product_taxes do |t|
			t.references :tax, :class => "wk_taxes", :null => false, :index => true
			t.references :product, :class => "wk_products", :null => false, :index => true
			t.timestamps null: false
		end
		
		create_table :wk_shipments do |t|
			t.string :serial_number
			t.string :shipment_type, :limit => 3
			t.date :shipment_date
			t.references :gl_transaction, :class => "wk_gl_transactions", :null => true, :index => true
			t.references :parent, polymorphic: true, index: true
			t.timestamps null: false
		end
		
		create_table :wk_locations do |t|
			t.string :name
			t.references :location_type, :class => "wk_crm_enumerations", :null => false, :index => true
			t.references :address, :class => "wk_addresses", :null => true, :index => true
			t.boolean :is_default
			t.timestamps null: false
		end
		
		create_table :wk_product_items do |t|
			t.references :product, :class => "wk_products", :null => false, :index => true
			t.references :brand, :class => "wk_brands", :null => true, :index => true
			t.references :product_model, :class => "wk_product_models", :null => true, :index => true
			t.string :part_number
			t.timestamps null: false
		end
		
		create_table :wk_inventory_items do |t|
			t.references :product_item, :class => "wk_product_items", :null => false, :index => true
			t.references :product_attribute, :class => "wk_product_attributes", :null => true, :index => true
			t.string :product_type, :limit => 3, :null => false, :default => 'I'
			t.string :notes
			t.string :status, :null => false, :limit => 5, :default => 'o'
			t.float :org_cost_price
			t.float :org_selling_price
			t.float :org_over_head_price
			t.column :org_currency, :string, :limit => 5
			t.float :cost_price
			t.float :selling_price
			t.float :over_head_price
			t.column :currency, :string, :limit => 5, :default => '$'
			t.float :total_quantity
			t.float :available_quantity
			t.references :uom, :class => "wk_mesure_units", :null => false, :index => true
			t.string :serial_number
			t.references :location, :class => "wk_locations", :null => true, :index => true
			t.references :supplier_invoice, :class => "wk_invoices", :null => true, :index => true
			t.references :shipment, :class => "wk_shipments", :null => true, :index => true
			t.integer :lock_version, :default => 0
			t.timestamps null: false
		end
		add_reference :wk_inventory_items, :parent, :class => "wk_inventory_items", :index => true
		
		create_table :wk_material_entries do |t|
		  t.column :project_id,  :integer,  :null => false
		  t.column :user_id,     :integer,  :null => false
		  t.column :issue_id,    :integer
		  t.column :quantity,    :float,    :null => false
		  t.column :quantity_returned,    :float
		  t.float :org_selling_price
		  t.boolean :is_deleted, :default => false
		  t.column :org_currency, :string, :limit => 5
		  t.float :selling_price
		  t.column :currency, :string, :limit => 5, :default => '$'
		  t.column :comments,    :string,   :limit => 255
		  t.column :activity_id, :integer,  :null => false
		  t.column :spent_on,    :date,     :null => false
		  t.column :tyear,       :integer,  :null => false
		  t.column :tmonth,      :integer,  :null => false
		  t.column :tweek,       :integer,  :null => false
		  t.column :created_on,  :datetime, :null => false
		  t.column :updated_on,  :datetime, :null => false
		  t.references :invoice_item, :class => "wk_invoice_items", :null => true, :index => true
		  t.references :inventory_item, :class => "wk_inventory_items", :index => true
		  t.references :uom, :class => "wk_mesure_units", :null => false, :index => true
		end
		add_index :wk_material_entries, [:project_id], :name => :wk_material_entries_project_id
		add_index :wk_material_entries, [:issue_id], :name => :wk_material_entries_issue_id
		
		reversible do |dir|
			dir.up do				
				add_reference :wk_invoice_items, :product, :class => "wk_products", :index => true
			end

			dir.down do
				remove_reference :wk_invoice_items, :product
			end 
		end
		
	end
end