class WkUserSalaryComponents < ActiveRecord::Base
  unloadable
  include Redmine::SafeAttributes
  
  belongs_to :user
  belongs_to :salary_component, :class_name => 'WkSalaryComponents', :foreign_key => 'salary_component_id'
  belongs_to :dependent, :class_name => 'User', :foreign_key => 'dependent_id'
  
  attr_protected :user_id, :salary_component_id, :dependent_id
end
