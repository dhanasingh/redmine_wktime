class WkAuthCode < ActiveRecord::Base
  self.table_name = 'wk_auth_codes'
  
  belongs_to :parent, polymorphic: true, optional: true

  validates_presence_of :type_value, :code
end
