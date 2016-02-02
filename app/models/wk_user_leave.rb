class WkUserLeave < ActiveRecord::Base
  unloadable
include Redmine::SafeAttributes

  belongs_to :user
  belongs_to :issue, :class_name => 'Issue', :foreign_key => 'issue_id'
  
  attr_protected :user_id, :issue_id
  safe_attributes 'balance', 'issue_id', 'accrual_on', 'used', 'accrual'
  
end
