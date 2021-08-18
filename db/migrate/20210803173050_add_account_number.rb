class AddAccountNumber < ActiveRecord::Migration[5.2]
  def change
    add_column :wk_accounts, :account_number, :string, default: nil
  end
end