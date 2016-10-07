class WkBillingSchedule < ActiveRecord::Base
  unloadable
  include Redmine::SafeAttributes
  
  belongs_to :account_project, :class_name => 'WkAccountProject', :foreign_key => 'account_project_id'
end
