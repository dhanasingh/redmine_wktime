class WkUserSalaryComponents < ActiveRecord::Base
  unloadable
  include Redmine::SafeAttributes
  
  belongs_to :user
  belongs_to :wk_salary_components, :class_name => 'WkSalaryComponents', :foreign_key => 'salary_component_id'
  belongs_to :wk_salary_components, :class_name => 'WkSalaryComponents', :foreign_key => 'dependent_id'
  
  attr_protected :user_id, :salary_component_id, :dependent_id
end
