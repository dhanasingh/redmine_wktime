class CreateWkAccounting < ActiveRecord::Migration
  def change
  
    create_table :wk_ledgers do |t|
      t.string :name
      t.decimal :opening_balance, :precision=>16, :scale=>2
	  t.column :currency, :string, :limit => 5
	  t.string :ledger_type, :null => false, :limit => 3
	  t.timestamps null: false
    end
	
	create_table :wk_transactions do |t|
      t.string :trans_type, :null => false, :limit => 3
	  t.date :trans_date, :null => false
      t.string :comment
	  t.timestamps null: false
    end
	
	create_table :wk_transaction_details do |t|
      t.references :ledger, :class => "wk_ledgers", :null => false
	  t.references :transaction, :class => "wk_transactions", :null => false
	  t.string :detail_type, :null => false, :limit => 3
	  t.decimal :amount, :precision=>16, :scale=>2
	  t.column :currency, :string, :limit => 5
	  t.decimal :original_amount, :precision=>16, :scale=>2
	  t.column :original_currency, :string, :limit => 5
	  t.timestamps null: false
    end
	add_index :wk_transaction_details, :ledger_id 
	add_index :wk_transaction_details, :transaction_id
	
  end
end
