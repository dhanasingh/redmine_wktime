require_dependency 'custom_field'
module EditCustomFields
  module CustomFieldPatch
    unloadable
    CustomField.has_many :wk_custom_fields, :foreign_key => "custom_fields_id", :primary_key => "id", dependent: :destroy
    extend ActiveSupport::Concern
  end
end
