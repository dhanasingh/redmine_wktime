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

class WkSalary < ApplicationRecord

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
    joins("LEFT JOIN wk_salary_components SC ON wk_salaries.salary_component_id = SC.id" + get_comp_con('SC'))
    .where("SC.component_type IN ('a', 'b') and salary_date between ? and ?", startDate, endDate)
    .group("user_id, salary_date")
    .select("user_id, salary_date, sum(amount) As amount")
  }

  scope :getSalaries, ->(userId, salaryDate){
    where({user_id: userId ,salary_date: salaryDate })
  }

  def self.getLastSalary
    WkSalary.joins(:salary_component)
    .joins("INNER JOIN (
      SELECT MAX(salary_date) AS salary_date, user_id
      FROM wk_salaries
      WHERE user_id=#{User.current.id} " + get_comp_con('wk_salaries') + "
      GROUP BY user_id
    ) AS T ON T.salary_date = wk_salaries.salary_date AND T.user_id = wk_salaries.user_id")
    .where("wk_salaries.user_id" => User.current.id)
    .group("currency, T.salary_date")
    .select("SUM(CASE WHEN wk_salary_components.component_type = 'a' THEN amount
      WHEN wk_salary_components.component_type = 'b' THEN amount
      ELSE 0 END) - SUM(CASE WHEN wk_salary_components.component_type = 'd' THEN amount ELSE 0 END) AS net, currency, T.salary_date")
    .order(:net).first
  end

  def self.lastIncrementSalary(all=false)
    salaries = {}
    data = {}
    dataSet = []
    oldBasic = nil
    oldSalaryDate = nil
    currency = ""

    wkSalaries = WkSalary.joins(:salary_component).where(user_id: User.current.id).order("salary_date DESC")
    wkSalaries.map{|s| salaries[s.salary_date.to_s] ||= wkSalaries.where(salary_date: s.salary_date)}
    salaries.each do |salaryDate, filtered|
      data = {}
      basic = nil
      filtered.map{|s| basic = s.amount if s.salary_component.component_type == "b"}
      if oldBasic.present? && oldBasic != basic
        data[:date] = oldSalaryDate
        net = 0
        (salaries[oldSalaryDate] || []).map do |s|
          net += s.amount if ["b", "a"].include? s.salary_component.component_type
          net -= s.amount if s.salary_component.component_type == "d"
          currency = s.currency
        end
        data[:value] = currency.to_s+ " " +sprintf('%.2f', net)
        if !all
          break
        else
          dataSet << data
          break if dataSet.length >= 12
        end
      end
      oldSalaryDate = salaryDate
      oldBasic = basic
    end
    return(all ? dataSet : data)
  end

  def self.lastYearSalaries
    WkSalary.joins(:salary_component)
      .where(user_id: User.current.id)
      .group("currency, salary_date")
      .select("SUM(CASE WHEN wk_salary_components.component_type = 'a' THEN amount
        WHEN wk_salary_components.component_type = 'b' THEN amount
        ELSE 0 END) - SUM(CASE WHEN wk_salary_components.component_type = 'd' THEN amount ELSE 0 END) AS net, currency, salary_date")
      .order("salary_date DESC")
  end
end
