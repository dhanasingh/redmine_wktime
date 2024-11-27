class WkSalCompCondition < ApplicationRecord
  belongs_to :salary_comp_dep, :class_name => 'WkSalCompDependent'
  validates_presence_of :lhs, :operators, :rhs, :rhs2
end