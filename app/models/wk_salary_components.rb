class WkSalaryComponents < ActiveRecord::Base
  Redmine::SafeAttributes
  has_many :salaries, foreign_key: "salary_component_id", class_name: "WkSalary"
end
