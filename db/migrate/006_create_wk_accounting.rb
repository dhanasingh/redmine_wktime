#!/bin/env ruby
# encoding: utf-8
class CreateWkAccounting < ActiveRecord::Migration[4.2]
  class WkLedger < ActiveRecord::Base
    # attr_protected :id
  end
  
  def change
  
    create_table :wk_ledgers do |t|
      t.string :name
      t.decimal :opening_balance, :precision=>16, :scale=>2
	  t.column :currency, :string, :limit => 5
	  t.string :ledger_type, :null => false, :limit => 3
	  t.string :owner, :null => false, :limit => 1, :default => 's'
	  t.timestamps null: false
    end
	
	create_table :wk_gl_transactions do |t|
      t.string :trans_type, :null => false, :limit => 3
	  t.date :trans_date, :null => false
      t.string :comment
	  t.timestamps null: false
    end
	
	create_table :wk_gl_transaction_details do |t|
      t.references :ledger, :class => "wk_ledgers", :null => false
	  t.references :gl_transaction, :class => "wk_gl_transactions", :null => false
	  t.string :detail_type, :null => false, :limit => 3
	  t.decimal :amount, :precision=>16, :scale=>2
	  t.column :currency, :string, :limit => 5
	  t.decimal :original_amount, :precision=>16, :scale=>2
	  t.column :original_currency, :string, :limit => 5
	  t.timestamps null: false
    end
	add_index :wk_gl_transaction_details, :ledger_id 
	add_index :wk_gl_transaction_details, :gl_transaction_id
	add_reference :wk_salary_components, :ledger, :class => "wk_ledgers", :null => true, index: true
	add_reference :wk_invoices, :gl_transaction, :class => "wk_gl_transactions", :null => true, index: true
	
	create_table :wk_gl_salaries do |t|
	  t.date :salary_date, :null => false
	  t.references :gl_transaction, :class => "wk_gl_transactions", :null => false
	  t.timestamps null: false
    end
	
	# create default ledgers
    ledger = WkLedger.new :name => 'Profit & Loss A/c',
                    :opening_balance => 0,
					:currency => "€",
                    :ledger_type => 'SY',
                    :owner => 's'            
    ledger.save
  end
end
