class WkCustomField < ActiveRecord::Base
  unloadable
  has_one :custom_field, :foreign_key => "id", :primary_key => "custom_fields_id"
end
