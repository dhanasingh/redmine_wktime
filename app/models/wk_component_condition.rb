class WkComponentCondition < ActiveRecord::Base
  belongs_to :wk_salary_components, :class_name => 'WkSalaryComponents'
  validates_presence_of :left_hand_side, :operators, :right_hand_side
end