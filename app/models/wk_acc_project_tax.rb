class WkAccProjectTax < ActiveRecord::Base
  unloadable
  belongs_to :account_project, :class_name => 'WkAccountProject', :foreign_key => 'account_project_id'
  belongs_to :tax, :class_name => 'WkTax'
end
