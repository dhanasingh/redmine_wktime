class WkSalary < ActiveRecord::Base
  unloadable
  include Redmine::SafeAttributes
  
  belongs_to :user
  belongs_to :salary_component, :class_name => 'WkSalaryComponents', :foreign_key => 'salary_component_id'
  
  attr_protected :user_id, :salary_component_id
end
