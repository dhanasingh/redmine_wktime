class CreateWkConsumedItems < ActiveRecord::Migration[6.1]
  def change
    add_column :wk_user_salary_components, :salary_type, :string, limit: 3
    add_column :wk_accounts, :tax_number, :string
    rename_table :wk_material_entry_sns, :wk_consumed_items
    add_reference :wk_consumed_items, :consumer, polymorphic: true
    add_column :wk_projects, :allow_consumed_items, :boolean, default: false
    add_reference :wk_crm_activities, :interview_type, class: "WkCrmEnumeration"
    reversible do |dir|
      dir.up do
        WkConsumedItems.all.each{|entry| entry.update_columns(consumer_id: entry.material_entry_id, consumer_type: 'WkMaterialEntry')}
      end
      dir.down do
        WkConsumedItems.where(consumer_type: 'WkMaterialEntry').all.each{|entry| entry.update_columns(material_entry_id: entry.consumer_id)}
        WkConsumedItems.where(material_entry_id: nil).delete_all
      end
    end
    remove_column :wk_consumed_items, :material_entry_id, :integer
  end
end
