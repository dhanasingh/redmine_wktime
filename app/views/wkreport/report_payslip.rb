# ERPmine - ERP for service industry
# Copyright (C) 2011-2021 Adhi software pvt ltd
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

module ReportPayslip
	include WkpayrollHelper

	def calcReportData(userId, groupId, projId, from, to)
		minSalaryDate = WkSalary.where("salary_date between '#{from}' and '#{to}'").minimum(:salary_date)
		if minSalaryDate.blank?
			@wksalaryEntries = nil
		else
			getSalaryDetail(userId,minSalaryDate.to_date)
			@userYTDAmountHash = getYTDDetail(userId,minSalaryDate.to_date)
		end
		componentHash = Hash.new()
		if @wksalaryEntries.present?
			componentHash['b'] = Array.new
			componentHash['a'] = Array.new
			componentHash['d'] = Array.new
			@wksalaryEntries.each do |entry|
				componentHash[entry.component_type] = componentHash[entry.component_type].blank? ? [[entry.component_name,entry.amount,entry.currency,@userYTDAmountHash[entry.sc_component_id]]] :  componentHash[entry.component_type] << [entry.component_name,entry.amount,entry.currency,@userYTDAmountHash[entry.sc_component_id]]
			end
		end
		period = @financialPeriod || []
		componentHash['e'] = (componentHash['b'] || []) + (componentHash['a'] || [])
		salaryVal = {userDetail: @wksalaryEntries&.first, salData: componentHash, start: period[0]&.strftime("%B %d, %Y"), end: period[1]&.strftime("%B %d, %Y"), total: getTotal(componentHash)}
		salaryVal
	end

	def getTotal(componentHash)
		total = Hash.new
		total[:e] = 0
		total[:ye] = 0
		total[:d] = 0
		total[:yd] = 0
		total[:r] = 0
		total[:yr] = 0
		componentHash.each do |type, salaryVal|
			salaryVal.each do |value|
				total[:cur] = value[2]
				if(['a', 'b'].include?(type))
					total[:e] += value[1] || 0
					total[:ye] += value[3] || 0
				elsif(['d'].include?(type))
					total[:d] += value[1] || 0
					total[:yd] += value[3] || 0
				elsif(['r'].include?(type))
					total[:r] += value[1] || 0
					total[:yr] += value[3] || 0
				end
			end
		end
		total[:net] = total[:e] - total[:d]
		total[:netYTD] = total[:ye] - total[:yd]
		total[:reimburse] = total[:e] - total[:d] + total[:r]
		total[:reimburseYTD] = total[:ye] - total[:yd] + total[:yr]
		total
	end
end