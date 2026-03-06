# Migration to create payment gateway transaction tracking tables
# These tables store payment gateway requests/responses before creating actual payments

class CreateWkPgPayment < ActiveRecord::Migration[6.1]
  def change
    # Main payment gateway transaction table
    create_table :wk_pg_payments do |t|
      # Status: IT (Initiated), SU (Success), FA (Failure), TE (Timeout/Terminated), AB (Aborted)
      t.string :status, limit: 5, default: 'IT'
      
      # Payment gateway identifiers
      t.string :pg_id, limit: 100  # Gateway tracking ID
      t.string :pg_pay_method, limit: 200  # Payment method used
      t.string :pg_msg, limit: 500  # Status message from gateway
      t.datetime :pg_trans_date  # Transaction date from gateway
      
      # Store full request/response for debugging and audit
      t.text :pg_request
      t.text :pg_response
      
      # Amount details
      t.decimal :amount, precision: 15, scale: 4
      t.string :currency, limit: 10
      t.decimal :original_amount, precision: 15, scale: 4
      t.string :original_currency, limit: 10
      
      # Parent association (Invoice)
      t.string :parent_type, limit: 50
      t.integer :parent_id
      
      # Link to actual payment after success
      t.integer :wk_payment_id, null: true
      
      # Audit fields
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :updated_by, foreign_key: { to_table: :users }
      
      t.timestamps
    end

    add_index :wk_pg_payments, :status
    add_index :wk_pg_payments, :pg_id
    add_index :wk_pg_payments, [:parent_type, :parent_id]

    # Payment gateway payment items - links invoices to pg payment
    create_table :wk_pg_payment_items do |t|
      t.references :wk_pg_payment, foreign_key: true, null: false
      t.integer :invoice_id, null: true
      
      # Amount details per invoice
      t.decimal :amount, precision: 15, scale: 4
      t.string :currency, limit: 10
      t.decimal :original_amount, precision: 15, scale: 4
      t.string :original_currency, limit: 10
      
      # Audit fields
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :updated_by, foreign_key: { to_table: :users }
      
      t.timestamps
    end

    add_index :wk_pg_payment_items, [:wk_pg_payment_id, :invoice_id], unique: true
  end
end
