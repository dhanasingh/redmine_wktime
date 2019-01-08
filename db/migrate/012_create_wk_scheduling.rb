class CreateWkScheduling  < ActiveRecord::Migration[4.2]

	def change
				
		create_table :wk_shifts do |t|
			t.string :name
			t.time :start_time
			t.time :end_time
			t.boolean :in_active, :default => true
			t.boolean :is_schedulable, :default => true
			t.references :created_by_user, :class => "User"
			t.references :updated_by_user, :class => "User"
			t.timestamps null: false
		end
		
		create_table :wk_shift_roles do |t|
			t.references :role, :null => false
			t.references :shift, :class => "wk_shifts", :index => true
			t.references :location, :class => "wk_crm_enumerations", :index => true
			t.references :department, :class => "wk_crm_enumerations", :index => true
			t.integer :staff_count, :default => 0			
			t.references :created_by_user, :class => "User"
			t.references :updated_by_user, :class => "User"
			t.timestamps null: false
		end
		
		create_table :wk_shift_schedules do |t|
			t.references :user, :null => false, :index => true
			t.references :shift, :class => "wk_shifts", :null => false, :index => true
			t.date :schedule_date
			t.string :schedule_as, :limit => 3, :default => 'W'	
			t.string :schedule_type, :limit => 3, :default => 'S'				
			t.references :created_by_user, :class => "User"
			t.references :updated_by_user, :class => "User"
			t.timestamps null: false
		end		
		
		create_table :wk_public_holidays do |t|
			t.date :holiday_date
			t.string :description
			t.references :location, :class => "wk_crm_enumerations",  :index => true			
			t.references :created_by_user, :class => "User"
			t.references :updated_by_user, :class => "User"
			t.timestamps null: false
		end
		
		create_table :wk_users do |t|
			t.references :user, :null => false, :index => true
			t.references :role, :index => true
			t.float :billing_rate
			t.boolean :is_schedulable, :default => true
			t.column :billing_currency, :string, :limit => 5, :default => '$'
			t.references :shift, :class => "wk_shifts", :null => true, :index => true
			t.references :location, :class => "wk_locations", :null => true, :index => true
			t.references :department, :class => "wk_crm_enumerations", :null => true, :index => true
			t.references :address, :class => "wk_addresses", :index => true
			t.date :join_date
			t.date :birth_date
			t.date :termination_date			
			t.date :custom_date1
			t.date :custom_date2
			t.string :gender, :limit => 3
			t.string :bank_name
			t.string :account_number	
			t.string :bank_code
			t.string :tax_id
			t.string :ss_id
			t.string :id1
			t.string :id2
			t.string :id3
			t.float :custom_number1
			t.float :custom_number2			
			t.references :created_by_user, :class => "User"
			t.references :updated_by_user, :class => "User"				
			t.timestamps null: false
		end
		
		reversible do |dir|
			dir.up do		
				add_column :wk_permissions, :modules, :string, :limit => 5
				execute <<-SQL
					INSERT INTO wk_permissions(id, name, short_name, modules, created_at, updated_at) VALUES (3, 'SCHEDULES SHIFT', 'S_SHIFT', 'SC', current_timestamp, current_timestamp);
				SQL
				
				execute <<-SQL
					INSERT INTO wk_permissions(id, name, short_name,modules, created_at, updated_at) VALUES (4, 'EDIT SHIFT SCHEDULES', 'E_SHIFT', 'SC', current_timestamp, current_timestamp);
				SQL
				
				execute <<-SQL
				  UPDATE wk_permissions set modules = 'IN' where name in ('INVENTORY_VIEW', 'INVENTORY_DELETE');
				SQL
				
				execute <<-SQL
				  UPDATE wk_permissions set name = 'VIEW INVENTORY' where name = 'INVENTORY_VIEW';
				SQL
				
				execute <<-SQL
				  UPDATE wk_permissions set name = 'DELETE INVENTORY' where name = 'INVENTORY_DELETE';
				SQL
				
				
			end
			dir.down do
				remove_column :wk_permissions, :modules
				
				execute <<-SQL
				  UPDATE wk_permissions set name = 'INVENTORY_VIEW' where name = 'VIEW INVENTORY';
				SQL
				
				execute <<-SQL
				  UPDATE wk_permissions set name = 'INVENTORY_DELETE' where name = 'DELETE INVENTORY';
				SQL
				
				execute <<-SQL
				  DELETE from wk_permissions where name = 'SCHEDULES SHIFT';
				SQL
				
				execute <<-SQL
				  DELETE from wk_permissions where name = 'EDIT SHIFT SCHEDULES';
				SQL
			end 
		end
	end
end