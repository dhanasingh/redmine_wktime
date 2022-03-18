class AddSupplierConfirmationNumber < ActiveRecord::Migration[5.2]
  def change
    add_column :wk_invoices, :confirm_num, :string
  end
end
