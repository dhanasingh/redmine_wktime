class CreateWkPurchase < ActiveRecord::Migration[4.2]

	def change
		
		#add column in wk_address table
		add_column :wk_invoices, :invoice_type, :string, :limit => 5, :default => 'I'
		add_column :wk_crm_contacts, :contact_type, :string, :limit => 5, :default => 'C'
		add_column :wk_invoices, :invoice_num_key, :integer
		add_reference :wk_payments, :gl_transaction, :class => "wk_gl_transactions"
		remove_reference :wk_payment_items, :gl_transaction, :class => "wk_gl_transactions", :null => true
		reversible do |dir|
			dir.up do
				execute <<-SQL
				  UPDATE wk_invoices set invoice_num_key = id;
				SQL
				# execute <<-SQL
				  # UPDATE wk_crm_contacts set contact_type = 'C' where account_id is null;
				# SQL
				remove_index :wk_invoices, :invoice_number
				add_index :wk_invoices, :invoice_number, :unique => false
				change_column :wk_invoice_items, :project_id, :integer, null: true
			end
			dir.down do
				execute <<-SQL
				   DELETE from wk_invoices where id in (select invoice_id from wk_invoice_items where project_id is null);
				 SQL
				execute <<-SQL
				  DELETE from wk_invoice_items where project_id is null;
				SQL
				remove_index :wk_invoices, :invoice_number
				add_index :wk_invoices, :invoice_number, :unique => true
				change_column :wk_invoice_items, :project_id, :integer, null: false
			end
		end
		
		#add_column :wk_crm_contacts, :contact_type, :string, :limit => 5, :default => 'C'
	
		create_table :wk_rfqs do |t|
			t.string :name
			t.string :description
			t.date :start_date
			t.date :end_date
			t.string :status, :null => false, :limit => 5, :default => 'o'
			t.references :created_by_user, :class => "User"
			t.references :modified_by_user, :class => "User"
			t.timestamps null: false
		 end
		
		create_table :wk_rfq_quotes do |t|
			t.references :rfq, :class => "wk_rf_quotes", :null => false, :index => true
			t.references :quote, :class => "wk_invoices", :null => true, :index => true
			t.boolean :is_won, :default => false
			t.string :winning_note
			t.date :won_date
			t.timestamps null: false
		end
		
		create_table :wk_po_quotes do |t|
			t.references :purchase_order, :class => "wk_invoices", :null => false, :index => true
			t.references :quote, :class => "wk_invoices", :null => true, :index => true
			t.timestamps null: false
		end
		
		create_table :wk_po_supplier_invoices do |t|
			t.references :purchase_order, :class => "wk_invoices", :null => false, :index => true
			t.references :supplier_inv, :class => "wk_invoices", :null => true, :index => true
			t.timestamps null: false
		end
		
		create_table :wk_te_locks do |t|
			t.column :lock_date,  :date,  :null => false
			t.column :locked_by,  :integer,  :null => false
			t.column :updated_by, :integer,  :null => true
			t.timestamps null: false
		end		
		
	end
end