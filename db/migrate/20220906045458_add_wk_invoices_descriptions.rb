class AddWkInvoicesDescriptions < ActiveRecord::Migration[6.1]
  def change
    add_column :wk_invoices, :description, :text
    reversible do |dir|
      dir.up do
        change_column :wk_addresses, :pin, :string, limit: 16
      end
    end
  end
end
