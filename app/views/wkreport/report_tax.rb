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

module ReportTax
	include WkreportHelper

	def calcReportData(userId, groupId, projId, from, to)
		from = from.to_date
		to = to.to_date
		betwn_mnth_count = getInBtwMonthsArr(from, to)
	
		if betwn_mnth_count.length > 12
			from = Date.civil(to.year,to.month, 1) - 11.month
			to = Date.civil((to + 1.month).year,(to + 1.month).month, 1) - 1
		end
	
		inBtwMonths = getInBtwMonthsArr(from, to)
		userSqlStr = getUserQueryStr(groupId, userId, from)
		userSqlStr += " order by employee_id"
		userList = User.find_by_sql(userSqlStr)
	
		queryStr = getQueryStr + 			
				"left join groups_users gu on (gu.user_id = u.id and gu.group_id = #{groupId}) " +
				"where u.type = 'User' and component_type != 'c'  and (wu.termination_date >= '#{from}' or (u.status = #{User::STATUS_ACTIVE} and wu.termination_date is null))"
		if groupId.to_i > 0 && userId.to_i < 1
			queryStr = queryStr + " and gu.group_id is not null"
		elsif userId.to_i > 0
			queryStr = queryStr + " and s.user_id = #{userId}"
		end
		
		queryStr = queryStr + " and s.salary_date  between '#{from}' and '#{to}' "
		
		if !(validateERPPermission('A_TE_PRVLG') || User.current.admin?)
			queryStr = queryStr + " and u.id = #{User.current.id} "
		end
	
		queryStr = queryStr + " order by s.user_id"
		salary_data = WkSalary.find_by_sql(queryStr)
		taxData = getTaxData(salary_data, userList, inBtwMonths)
		tax = {taxData: taxData, from: from.to_formatted_s(:long), to: to.to_formatted_s(:long)}
		tax
	end

	def getTaxData(salary_data, userList, inBtwMonths)	
		tds_id = WkSetting.where("name = 'income_tax'").first
		taxData = {}
		tdsHash = {}
		grossHash = {}
		inBtwMonths.each do |month|
			key = (month.first).to_s  + "_"  + (month.last).to_s
			taxData[key] = {}
			taxData[key]['users'] = []
			tdsHash[key] = {}
			grossHash[key] = {}
			grossTot = cessTot = tdsTot = total = 0
			userList.each do |user|
				user_id = user.id.to_s
				tdsHash[key][user_id] = 0
				grossHash[key][user_id] = 0
				salary_data.each do |entry|
					sal_key = entry.salary_date.strftime("%Y") + "_" + entry.salary_date.strftime("%-m")
					if (entry.component_type == 'b' || entry.component_type == 'a') && user.id == entry.user_id && sal_key == key
						grossHash[key][user_id] = entry.amount + grossHash[key][user_id]
					end
					if tds_id.value.to_i == entry.sc_component_id && user.id == entry.user_id && sal_key == key
						tdsHash[key][user_id] = entry.amount
					end
				end
				if tdsHash[key][user_id] > 0
					tds = cess = 0
					tds = (tdsHash[key][user_id]/1.04).round() if tdsHash[key][user_id].present?
					cess =  (tdsHash[key][user_id] - tds) if tdsHash[key][user_id].present?
					grossTot += grossHash[key][user_id]
					total += tdsHash[key][user_id]
					cessTot += cess
					tdsTot += tds
					taxData[key]['users'] << {employee_id: user.employee_id, tax_id: user.tax_id, name: user.name, gross: grossHash[key][user_id], taxTotal: tdsHash[key][user_id], tds: tds, cess: cess}
				end
			end
			taxData[key]['grossTot'] =  grossTot
			taxData[key]['cessTot'] =  cessTot
			taxData[key]['tdsTot'] =  tdsTot
			taxData[key]['total'] =  total
			taxData[key]['month_name'] =  Date::MONTHNAMES[month.last].to_s + " " + month.first.to_s
		end
		taxData
	end
end