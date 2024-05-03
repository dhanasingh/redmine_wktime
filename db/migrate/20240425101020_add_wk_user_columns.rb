class AddWkUserColumns < ActiveRecord::Migration[6.1]
    def change
      add_column :wk_users, :state_insurance, :string
      add_column :wk_users, :employee_id, :string
      add_column :wk_users, :emergency_contact, :string, limit: 50
      add_column :wk_users, :notes, :text
      add_reference :wk_users, :marital, :class => "WkCrmEnumeration"
      add_reference :wk_users, :emerg_type, :class => "WkCrmEnumeration"
      add_reference :wk_users, :dept_section, :class => "WkCrmEnumeration"
    end
  end 
