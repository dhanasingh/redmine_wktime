class WkSalCompDependent < ApplicationRecord
    belongs_to :salary_comp, :class_name => 'WkSalaryComponents', :foreign_key => 'salary_component_id'
    has_one :salary_comp_cond, foreign_key: "sal_comp_dep_id", class_name: "WkSalCompCondition"

  	accepts_nested_attributes_for :salary_comp_cond, allow_destroy: true
end