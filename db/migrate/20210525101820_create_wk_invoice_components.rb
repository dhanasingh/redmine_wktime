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

    add_column :wk_material_entries, :author_id, :integer, default: nil

    reversible do |dir|
      dir.up do
        # Copy existing user_id to author_id
        WkMaterialEntry.update_all('author_id = user_id')
      end
    end
    
  end
end