class ChangeDescriptionColumnType < ActiveRecord::Migration[5.2]
  def change
    reversible do |dir|
      dir.up do
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
  end
end