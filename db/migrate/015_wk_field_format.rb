class WkFieldFormat < ActiveRecord::Migration
  def self.up
    create_table :wk_custom_fields do |t|
      t.references :custom_fields, null:false
      t.string :display_as, null:false
      t.references :projects
      t.boolean :allow_users_change_project
      t.references :enumerations
      t.boolean :render_creation
    end
  end

  def self.down
    CustomField.where(field_format: ["company","wk_lead","crm_contact"]).destroy_all
    drop_table :wk_custom_fields
  end
end
