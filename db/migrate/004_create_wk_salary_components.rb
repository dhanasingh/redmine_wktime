class CreateWkSalaryComponents < ActiveRecord::Migration[4.2]
  def change
    create_table :wk_salary_components do |t|
      t.string :name
      t.string :frequency, :null => true, :limit => 3
      t.date :start_date
      t.string :component_type, :null => false, :limit => 3
	  t.references :dependent, :class => "WkSalaryComponents", :null => true
      t.float :factor
      t.string :salary_type, :null => true, :limit => 3
	  t.timestamps null: false
    end
	
	create_table :wk_user_salary_components do |t|
      t.references :user, :null => false
	  t.references :salary_component, :class => "WkSalaryComponents", :null => false
	  t.references :dependent, :class => "WkSalaryComponents", :null => true
      t.float :factor
	  t.timestamps null: false
    end
	add_index  :wk_user_salary_components, :user_id
	add_index  :wk_user_salary_components, :salary_component_id
	
	create_table :wk_salaries do |t|
      t.references :user, :null => false
	  t.references :salary_component, :class => "WkSalaryComponents", :null => false
      t.float :amount
      t.date :salary_date
	  t.column :currency, :string, :limit => 5, :default => '$'
	  t.timestamps null: false
    end
	add_index  :wk_salaries, :user_id
	add_index  :wk_salaries, :salary_component_id
	add_index  :wk_salaries, :salary_date
	
	create_table :wk_h_user_salary_components do |t|
      t.references :user, :null => false
	  t.references :user_salary_component, :class => "WkUserSalaryComponents", :null => false
	  t.references :salary_component, :class => "WkSalaryComponents", :null => false
	  t.references :dependent, :class => "WkSalaryComponents", :null => true
      t.float :factor
	  t.timestamps null: false
    end

  end
end
