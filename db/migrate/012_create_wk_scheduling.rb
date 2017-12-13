class CreateWkScheduling  < ActiveRecord::Migration

	def change
		create_table :wk_users do |t|
			t.references :user, :null => false, :index => true
			t.references :role
			t.integer :id1
			t.integer :id2
			t.integer :id3
			t.date :join_date
			t.date :birth_date
			t.date :termination_date
			t.string :gender, :limit => 3
			t.float :billing_rate
			t.column :biling_currency, :string, :limit => 5, :default => '$'
			t.references :location, :class => "wk_locations", :null => false, :index => true
			t.references :department, :class => "wk_crm_enumerations", :null => false, :index => true
			t.timestamps null: false
		end
		
		create_table :wk_shifts do |t|
			t.string :name
			t.time :start_time
			t.time :end_time
			t.boolean :in_active
			t.timestamps null: false
		end
		
		create_table :wk_shift_roles do |t|
			t.references :role, :null => false
			t.references :shift, :class => "wk_shifts", :index => true
			t.references :location, :class => "wk_crm_enumerations", :null => false, :index => true
			t.references :department, :class => "wk_crm_enumerations", :null => false, :index => true
			t.integer :staff_count, :default => 0
			t.timestamps null: false
		end
		
		create_table :wk_shift_schedules do |t|
			t.references :user, :null => false, :index => true
			t.references :shift, :class => "wk_shifts", :null => false, :index => true
			t.date :schedule_date
			t.string :schedule_as, :limit => 3, :default => 'W'
			t.timestamps null: false
		end
		
		create_table :wk_shift_priorities do |t|
			t.references :user, :null => false, :index => true
			t.references :shift, :class => "wk_shifts", :null => false, :index => true
			t.date :start_date
			t.string :preference_type, :limit => 3, :default => 'W'
			t.integer :priority
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