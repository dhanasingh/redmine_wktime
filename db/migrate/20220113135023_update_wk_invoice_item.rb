class UpdateWkInvoiceItem < ActiveRecord::Migration[5.2]
  def change
    add_reference :wk_invoice_items, :invoice_item, polymorphic: true, index: true
  end
end