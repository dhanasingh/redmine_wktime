class WkAttendance < ActiveRecord::Base
  unloadable
  include Redmine::SafeAttributes
  
  belongs_to :user
  
  acts_as_customizable
  attr_protected :user_id
  safe_attributes 'start_time', 'end_time', 'week_date'
  
  validates_presence_of :user_id, :start_time, :start_time, :week_date
end
