class CreateWkInvoiceComponents < ActiveRecord::Migration[5.2]
  def change

    create_table :wk_invoice_components do |t|
      t.string :name
      t.string :value
      t.string :comp_type
      t.timestamps null: false
    end

    create_table :wk_acc_invoice_components do |t|
      t.references :account_project, class: "WkAccountProject", null: false
      t.references :invoice_component, class: "WkInvoiceComponents", null: false
      t.string :value
      t.timestamps null: false
    end
    
  end
end