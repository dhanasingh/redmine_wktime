class CreateWkBilling < ActiveRecord::Migration[4.2]
  def change
	create_table :wk_addresses do |t|
	  t.string :address1
      t.string :address2
	  t.string :work_phone
      t.string :home_phone
	  t.string :mobile
      t.string :email
	  t.string :fax
      t.string :city
	  t.string :country
      t.string :state
      t.integer :pin
	  t.timestamps null: false
    end
  
    create_table :wk_accounts do |t|
      t.string :name
      t.string :account_type, :null => true, :limit => 3
	  t.boolean :account_billing, :default => false
	  t.references :address, :class => "wk_addresses", :null => true
	  t.timestamps null: false
    end
	
	
	create_table :wk_account_projects do |t|
      t.boolean :itemized_bill
	  t.boolean :apply_tax
      t.string :billing_type, :null => true, :limit => 3
      t.references :project, :null => true
	  t.references :account, :class => "wk_accounts", :null => true
	  t.timestamps null: false
    end	
	
	create_table :wk_contracts do |t|
      t.references :project, :null => true
	  t.references :account, :class => "wk_accounts", :null => true
	  t.date :start_date
	  t.date :end_date
      t.string :contract_number,         :null => false
      t.timestamps null: false
    end
	
	create_table :wk_taxes do |t|
      t.string :name
      t.float :rate_pct
	  t.boolean :is_active, :default => true
      t.timestamps null: false
    end
	
	create_table :wk_acc_project_taxes do |t|
      t.references :account_project, :class => "wk_account_projects", :null => false
      t.references :tax, :class => "wk_taxes", :null => false
      t.timestamps null: false
    end
	
	create_table :wk_invoices do |t|
      t.string :status, :null => false, :limit => 3, :default => 'o'
	  t.string :invoice_number, :null => false
      t.date :start_date
	  t.date :end_date
	  t.date :invoice_date
	  t.datetime :closed_on
	  t.references :modifier, :class => "User", :null => false
	  t.references :account, :class => "wk_accounts", :null => false
	  t.timestamps null: false
    end
	
	create_table :wk_invoice_items do |t|
      t.string :name
	  t.decimal :rate, :precision=>16, :scale=>2
      t.decimal :amount, :precision=>16, :scale=>2
	  t.float :quantity
	  t.string :item_type, :null => false, :limit => 3, :default => 'i'
	  t.column :currency, :string, :limit => 5, :default => '$'
	  t.references :project, :null => false
	  t.references :modifier, :class => "User", :null => false
	  t.references :invoice, :class => "wk_invoices", :null => false
	  t.timestamps null: false
    end
	
	create_table :wk_billing_schedules do |t|
	  t.string :milestone
      t.date :bill_date
      t.decimal :amount, :precision=>16, :scale=>2
	  t.column :currency, :string, :limit => 5, :default => '$'
	  t.references :invoice, :class => "wk_invoices", :null => true
	  t.references :account_project, :class => "wk_account_projects", :null => false
	  t.timestamps null: false
    end
	
	reversible do |dir|
	  dir.up do
		add_index  :wk_accounts, :address_id
		add_index  :wk_account_projects, :project_id
		add_index  :wk_account_projects, :account_id
		add_index  :wk_contracts, :project_id
		add_index  :wk_contracts, :account_id
		add_index  :wk_acc_project_taxes, :account_project_id
		add_index  :wk_acc_project_taxes, :tax_id		
		add_index  :wk_invoices, :account_id 
		add_index :wk_invoices, :invoice_number, :unique => true		
		add_index  :wk_invoice_items, :invoice_id
		add_index  :wk_invoice_items, :project_id
		add_index  :wk_billing_schedules, :account_project_id
		add_index  :wk_billing_schedules, :invoice_id
	  end	  
	end

  end
end
