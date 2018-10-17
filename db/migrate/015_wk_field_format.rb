class WkFieldFormat < ActiveRecord::Migration
  def self.up
    create_table :wk_custom_fields do |t|
      t.references :custom_fields, null:false
      t.string :display_as, null:false
      t.references :projects
      t.boolean :allow_users_change_project
      t.references :enumerations
      t.boolean :allow_users_change_enumeration
      t.boolean :render_creation
    end
  end

  def self.down
    drop_table :wk_custom_fields
    CustomField.where(field_format: ["company","wk_lead","crm_contact"]).destroy_all
  end
end
