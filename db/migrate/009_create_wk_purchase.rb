class CreateWkPurchase < ActiveRecord::Migration

	def change
		
		#add column in wk_address table
		add_column :wk_invoices, :invoice_type, :string, :limit => 5, :default => 'I'
		add_column :wk_invoices, :invoice_num_key, :integer
		add_reference :wk_payments, :gl_transaction, :class => "wk_gl_transactions"
		remove_reference :wk_payment_items, :gl_transaction, :class => "wk_gl_transactions", :null => true
		reversible do |dir|
			dir.up do
				# add a CHECK constraint
				execute <<-SQL
				  UPDATE wk_invoices set invoice_num_key = id;
				SQL
			end
		end
		
		add_column :wk_crm_contacts, :contact_type, :string, :limit => 5, :default => 'C'
	
		create_table :wk_rfqs do |t|
			t.string :name
			t.string :description
			t.date :start_date
			t.date :end_date
			t.column :status, :string, :limit => 5
			t.references :created_by_user, :class => "User"
			t.references :modified_by_user, :class => "User"
			t.timestamps null: false
		 end
		
		create_table :wk_rfq_quotes do |t|
			t.references :rfq, :class => "wk_rf_quotes", :null => false, :index => true
			t.references :quote, :class => "wk_invoices", :null => true, :index => true
			t.boolean :is_won
			t.timestamps null: false
		end
		
		create_table :wk_po_quotes do |t|
			t.references :po, :class => "wk_invoices", :null => false, :index => true
			t.references :quote, :class => "wk_invoices", :null => true, :index => true
			t.timestamps null: false
		end
	end
end