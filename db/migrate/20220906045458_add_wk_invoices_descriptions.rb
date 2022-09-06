class AddWkInvoicesDescriptions < ActiveRecord::Migration[6.1]
  def change
    add_column :wk_invoices, :description, :text
  end
end
