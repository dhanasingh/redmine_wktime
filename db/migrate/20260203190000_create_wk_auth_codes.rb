class CreateWkAuthCodes < ActiveRecord::Migration[6.1]
  def change
    create_table :wk_auth_codes do |t|
      t.string :type_value
      t.string :otp_type, limit: 2, default: 'E'
      t.string :code
      t.string :ip_address
      t.string :parent_type
      t.integer :parent_id
      t.boolean :is_verified, default: false
      t.datetime :verified_at
      t.datetime :expires_at
      t.integer :attempts, default: 0

      t.timestamps
    end
    
    add_index :wk_auth_codes, :type_value
    add_index :wk_auth_codes, [:parent_type, :parent_id]
  end
end
