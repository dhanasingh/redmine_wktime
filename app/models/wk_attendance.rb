class WkAttendance < ActiveRecord::Base
  unloadable
  include Redmine::SafeAttributes
  
  belongs_to :user
  
  acts_as_customizable
  attr_protected :user_id
  safe_attributes 'start_time', 'end_time'
  
  validates_presence_of :user_id
end
