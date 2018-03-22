class CreateWkResidentManagement  < ActiveRecord::Migration

	def change
		
		create_table :wk_spent_fors do |t|
			t.references :spent_for, polymorphic: true, index: true
			t.references :spent, polymorphic: true, index: true
			t.datetime :spent_on_time
			t.references :invoice_item, :class => "wk_invoice_items", :null => true, :index => true
		end
		
		add_reference :wk_accounts, :location, :class => "wk_locations", :null => true, :index => true
		
		add_reference :wk_crm_contacts, :location, :class => "wk_locations", :null => true, :index => true
		
		add_reference :wk_crm_contacts, :contact, :class => "wk_crm_contacts", :null => true, index: true
		
		add_reference :wk_crm_contacts, :relationship, :class => "wk_crm_enumerations", :null => true, :index => true
		
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