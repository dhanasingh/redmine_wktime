class WkUserLeave < ActiveRecord::Base
  unloadable
include Redmine::SafeAttributes

  belongs_to :user
  belongs_to :issue, :class_name => 'Issue', :foreign_key => 'issue_id'
  
end
