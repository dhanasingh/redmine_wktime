class WkFieldFormat < ActiveRecord::Migration
  def self.up
    create_table :wk_custom_fields do |t|
      t.references :custom_fields
      t.string :display_as
    end
  end

  def self.down
    drop_table :wk_custom_fields
    CustomField.where(field_format: ["company","wk_lead","crm_contact"]).destroy_all
  end
end
