class CreateWkPayment < ActiveRecord::Migration[4.2]

	def change
		
		add_reference :wk_invoices, :parent, polymorphic: true, index: true
		add_reference :wk_contracts, :parent, polymorphic: true, index: true
		add_reference :wk_account_projects, :parent, polymorphic: true, index: true
		
		reversible do |dir|
		  dir.up do
			# add a CHECK constraint
			execute <<-SQL
			  UPDATE wk_invoices set parent_id = account_id, parent_type = 'WkAccount' ;
			SQL
			execute <<-SQL
			  UPDATE wk_contracts set parent_id = account_id, parent_type = 'WkAccount' ;
			SQL
			execute <<-SQL
			  UPDATE wk_account_projects set parent_id = account_id, parent_type = 'WkAccount' ;
			SQL
		  end
		  dir.down do
			execute <<-SQL
			   UPDATE wk_invoices set account_id = parent_id ;
			SQL
			execute <<-SQL
			  UPDATE wk_contracts set account_id = parent_id ;
			SQL
			execute <<-SQL
			  UPDATE wk_account_projects set account_id = parent_id;
			SQL
		
			
		  end
		end
	
	
	
		create_table :wk_payments do |t|
			t.date :payment_date
			t.string :description
			t.references :payment_type, :class => "wk_crm_enumerations"
			t.string :reference_number
			t.references :parent, polymorphic: true, index: true
			t.references :created_by_user, :class => "User"
			t.references :modified_by_user, :class => "User"
			t.timestamps null: false
		 end
		
		create_table :wk_payment_items do |t|
			t.float :amount
			t.column :currency, :string, :limit => 5
			t.boolean :is_deleted, :default => false
			t.references :payment, :class => "wk_payments", :null => true, :index => true
			t.references :invoice, :class => "wk_invoices", :null => true, :index => true
			t.references :gl_transaction, :class => "wk_gl_transactions", :null => true, :index => true
			t.references :created_by_user, :class => "User"
			t.references :modified_by_user, :class => "User"
			t.timestamps null: false
		end
		
		create_table :wk_ex_currency_rates do |t|
			t.column :from_c, :string, :limit => 5, :default => '$'
			t.column :to_c, :string, :limit => 5, :default => '$'
			t.float :ex_rate
			t.timestamps null: false
		end
		
		add_reference :wk_invoice_items, :credit_invoice, :class => "wk_invoices"
		add_reference :wk_invoice_items, :credit_payment_item, :class => "wk_payment_items"
		remove_reference :wk_invoices, :account, :class => "wk_accounts", :null => true 
		remove_reference :wk_contracts, :account, :class => "wk_accounts", :null => true
		remove_reference :wk_account_projects, :account, :class => "wk_accounts", :null => true
	end
end