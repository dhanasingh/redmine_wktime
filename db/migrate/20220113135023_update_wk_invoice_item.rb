class UpdateWkInvoiceItem < ActiveRecord::Migration[5.2]
  def change
    add_reference :wk_invoice_items, :invoice_item, polymorphic: true, index: true
    reversible do |dir|
      dir.up do
        change_column :wk_inventory_items, :notes, :text
      end
    end
    add_column :wk_inventory_items, :invoice_item_id, :integer, default: nil
  end
end