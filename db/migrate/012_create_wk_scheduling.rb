class CreateWkScheduling  < ActiveRecord::Migration

	def change
		create_table :wk_users do |t|
			t.references :user, :null => false, :index => true
			t.references :role
			t.date :join_date
			t.date :birth_date
			t.date :termination_date
			t.string :gender, :limit => 3
			t.float :billing_rate
			t.column :biling_currency, :string, :limit => 5, :default => '$'
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
			t.integer :staff_count, :default => 0
			t.timestamps null: false
		end
		
		create_table :wk_shift_schedules do |t|
			t.references :user, :null => false, :index => true
			t.references :shift, :class => "wk_shifts", :null => false, :index => true
			t.date :shift_date
			t.string :schedule_as, :limit => 3, :default => 'W'
			t.timestamps null: false
		end
		
		create_table :wk_shift_priorities do |t|
			t.references :user, :null => false, :index => true
			t.references :shift, :class => "wk_shifts", :null => false, :index => true
			t.date :start_date
			t.integer :priority
			t.timestamps null: false
		end
	end
end