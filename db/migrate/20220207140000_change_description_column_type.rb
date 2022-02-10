class ChangeDescriptionColumnType < ActiveRecord::Migration[5.2]
  def up
    change_column :wk_expense_entries, :comments, :string, limit: 1024
    change_column :wk_material_entries, :comments, :string, limit: 1024
    change_column :wk_inventory_items, :notes, :text
    change_column :wk_delivery_items, :notes, :text
    change_column :wk_crm_contacts, :description, :text
    change_column :wk_accounts, :description, :text
    change_column :wk_opportunities, :description, :text
    change_column :wk_rfqs, :description, :text
    change_column :wk_products, :description, :text
    change_column :wk_brands, :description, :text
    change_column :wk_product_models, :description, :text
    change_column :wk_product_attributes, :description, :text
    change_column :wk_attribute_groups, :description, :text
  end
end