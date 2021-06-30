# ERPmine - ERP for service industry
# Copyright (C) 2011-2016  Adhi software pvt ltd
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class WkSalary < ActiveRecord::Base
  unloadable
  include Redmine::SafeAttributes
  
  belongs_to :user
  belongs_to :salary_component, :class_name => 'WkSalaryComponents', :foreign_key => 'salary_component_id'
  
  scope :get_gross, ->(userID, from_date, to_date){
    joins(:salary_component)
    .where("component_type IN ('b','a') AND user_id = ? AND salary_date BETWEEN ? and ?", userID, from_date, to_date)
    .select("sum(amount) AS gross_amount, wk_salaries.user_id")
    .group("wk_salaries.user_id")
  }
  
  scope :getUserSalaries, ->(startDate, endDate){
    joins("LEFT JOIN wk_salary_components SC ON wk_salaries.salary_component_id = SC.id")
    .where("SC.component_type IN ('a', 'b') and salary_date between ? and ?", startDate, endDate)
    .group("user_id, salary_date")
    .select("user_id, salary_date, sum(amount) As amount")
  }

  scope :getSalaries, ->(userId, salaryDate){
    where({user_id: userId ,salary_date: salaryDate })
  }
end
