class CreateWkResidentManagement  < ActiveRecord::Migration

	def change
		create_table :rm_resident_sevices do |t|
			t.references :resident, polymorphic: true, index: true
			t.references :issue, :null => false
			t.date :start_date
			t.date :end_date
			t.string :frequency, :null => false, :limit => 2, :default => 'M'
			# t.string :requirement_type, :null => false, :limit => 2, :default => 'S'
			t.integer :no_of_occurrence, :default => 0		
			t.references :created_by_user, :class => "User"
			t.references :updated_by_user, :class => "User"
			t.timestamps null: false
		end
		
		create_table :rm_residents do |t|
			t.references :resident, polymorphic: true, index: true
			t.date :move_in_date
			t.date :move_out_date
			t.references :inventory_item, :class => "wk_inventory_items", :index => true
			t.references :created_by_user, :class => "User"
			t.references :updated_by_user, :class => "User"
			t.timestamps null: false
		end
		
		create_table :wk_spent_fors do |t|
			t.references :spent_for, polymorphic: true, index: true
			t.references :spent, polymorphic: true, index: true
			t.datetime :spent_on_time
			t.references :invoice_item, :class => "wk_invoice_items", :null => true, :index => true
		end
		
		add_reference :wk_crm_contacts, :contact, :class => "wk_crm_contacts", :null => true, index: true
		
		reversible do |dir|
			dir.up do
				add_reference :wk_inventory_items, :from, :class => "wk_inventory_items", :index => true
				
				execute <<-SQL
				  UPDATE wk_inventory_items set from_id = parent_id;
				SQL
				
				execute <<-SQL
				  UPDATE wk_inventory_items set parent_id = null;
				SQL
			end

			dir.down do				
				execute <<-SQL
				  UPDATE wk_inventory_items set parent_id = from_id;
				SQL
				remove_reference :wk_inventory_items, :from
			end 
		end
	end
end