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

module ReportPf
	include WkreportHelper

	def calcReportData(userId, groupId, projId, from, to)
		from = from.to_date
    to = (from >> 1) - 1

		queryStr = " select U.id ,U.firstname, U.lastname , S.amount, WKU.retirement_account, S.salary_date from users U
									LEFT JOIN wk_users WKU ON WKU.user_id = U.id
									LEFT JOIN wk_salaries S ON S.user_id = U.id and  S.salary_date between '#{from}' and '#{to}'
									LEFT JOIN wk_salary_components SC ON SC.id = S.salary_component_id"
		sqlwhere = " where U.type = 'User' and (SC.component_type ='b' OR SC.component_type IS NULL) and (WKU.termination_date >= '#{from}' or (U.status = 1 and WKU.termination_date is null))"
		if groupId.to_i > 0
			queryStr = queryStr + " LEFT JOIN groups_users GU on (GU.user_id = U.id )"
			sqlwhere = sqlwhere + " and gu.group_id =#{groupId}" if userId.to_i < 1
			sqlwhere = sqlwhere + " and GU.group_id =#{groupId} and U.id =#{userId}" if userId.to_i > 0
		elsif userId.to_i > 0
			sqlwhere = sqlwhere + " and U.id =#{userId}"
		end		

    if !(validateERPPermission('A_TE_PRVLG') || User.current.admin?)
      sqlwhere = sqlwhere + " and U.id =#{User.current.id}"
    end

		salary_data = WkSalary.find_by_sql(queryStr + sqlwhere)
		pfData = getPFData(salary_data)
		salary_date = salary_data&.first&.salary_date.present? ? salary_data.first.salary_date : from
		tax = {data: pfData[:data], total: pfData[:total], from: salary_date.to_formatted_s(:long)}
		tax
	end

	def getPFData(salary_data)
		pf_data = {}
		total = {}
		total[:basicTot] = 0
		total[:wagesTot] = 0
		total[:eeTot] = 0
		total[:erTot] = 0
		total[:epsTot] = 0
		salary_data.each do |entry|
			key = entry.id
			pf_data[key] = {} if pf_data[key].blank?
			basic = entry.amount || 0
			wages = basic < 15000 ? basic : 15000
			emp_share = (basic * 0.12).round()
			eps_share = (wages * 0.0833).round()
			emr_share = (wages * 0.0367).round()
			total[:basicTot] += basic.round()
			total[:wagesTot] += wages.round()
			total[:eeTot] += emp_share
			total[:erTot] += emr_share
			total[:epsTot] += eps_share
			pf_data[key][:uan] = entry.retirement_account
			pf_data[key][:name] = entry.firstname.to_s + " "+entry.lastname.to_s
			pf_data[key][:basic] = basic.round()
			pf_data[key][:eps] = wages.round()
			pf_data[key][:ee] = emp_share
			pf_data[key][:eps_remitted] = eps_share
			pf_data[key][:er] = emr_share
		end
		return {data: pf_data, total: total}
	end
end