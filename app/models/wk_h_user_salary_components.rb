class WkHUserSalaryComponents < ActiveRecord::Base
  unloadable
  include Redmine::SafeAttributes
  
  belongs_to :user
  belongs_to :user_salary_component, :class_name => 'WkUserSalaryComponents', :foreign_key => 'user_salary_component_id'
  
  attr_protected :user_id, :user_salary_component_id
end
