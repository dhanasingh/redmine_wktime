class WkFieldFormat < ActiveRecord::Migration
  def self.down
    CustomField.where(field_format: ["company","wk_lead","crm_contact"]).destroy_all
  end
end
