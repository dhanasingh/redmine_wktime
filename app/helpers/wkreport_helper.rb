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

module WkreportHelper	
	include WktimeHelper
	include WkaccountingHelper
	include WkcrmHelper
	include WkpayrollHelper
	include WkattendanceHelper

	def options_for_period_select(value)
		options_for_select([
							[l(:label_this_week), 'current_week'],
							[l(:label_last_week), 'last_week'],
							[l(:label_this_month), 'current_month'],
							[l(:label_last_month), 'last_month']],
							value.blank? ? 'current_week' : value)
	end	

	def options_for_report_select(selectedRpt)
		reportTypeArr = [ 
			[l(:label_wk_timesheet), 'report_time'], 			
			[l(:label_wk_expensesheet), 'report_expense']]
			
		Dir["plugins/redmine_wktime/app/views/wkreport/_report*"].each do |f|
		  fileName = File.basename(f, ".html.erb")
		  fileName.slice!(0)
		  reportTypeArr << [l(:"#{fileName}"), fileName] if hasViewPermission(fileName)
		end
		reportTypeArr.sort!
		options_for_select(reportTypeArr, selectedRpt)
	end
	
	def hasViewPermission(reportName)
		ret = true
		if reportName == 'report_profit_loss' || reportName == 'report_balance_sheet' || reportName == 'report_trial_balance'
			ret = validateERPPermission("B_ACC_PRVLG") || validateERPPermission("A_ACC_PRVLG")
		elsif reportName == 'report_lead_conversion' || reportName == 'report_sales_activity'
			ret = (validateERPPermission("B_CRM_PRVLG") || validateERPPermission("A_CRM_PRVLG") ) && isChecked('wktime_enable_crm_module')
		elsif reportName == 'report_order_to_cash' || reportName == 'report_project_profitability'
			ret = validateERPPermission("M_BILL")
		end
		ret
	end
	
	def getUserQueryStr(group_id,user_id, from)
		queryStr = "select u.id , gu.group_id, u.firstname, u.lastname,wu.termination_date, wu.join_date, " +
			"wu.birth_date, wu.id1 as employee_id, rs.name as designation, wu.gender, wu.account_number, wu.bank_code from users u " +
			"left join groups_users gu on (gu.user_id = u.id and gu.group_id = #{group_id}) " +
			"left join wk_users wu on u.id = wu.user_id " +
			"left join roles rs on rs.id = wu.role_id " +
			"where u.type = 'User' and ( wu.termination_date >= '#{from}' or (u.status = #{User::STATUS_ACTIVE} and wu.termination_date is null))"
		if group_id.to_i > 0 && user_id.to_i < 1
			queryStr = queryStr + " and gu.group_id is not null"
		elsif user_id.to_i > 0
			queryStr = queryStr + " and u.id = #{user_id}"
		end
		
		if !(validateERPPermission('A_TE_PRVLG') || User.current.admin?)
			queryStr = queryStr + " and u.id = #{User.current.id} "
		end
		#queryStr = queryStr + " order by u.created_on"
		queryStr
	end
	
	def getReportLeaveIssueIds
		issueIds = ''
		if(Setting.plugin_redmine_wktime['wktime_leave'].blank?)
			issueIds = '-1'
		else
			Setting.plugin_redmine_wktime['wktime_leave'].each_with_index do |element,index|
				if index < 3
					if issueIds!=''
						issueIds = issueIds +','
					end
				  listboxArr = element.split('|')
				  issueIds = issueIds + listboxArr[0]
				end
			end
		end	
		issueIds
	end
	
	def getTotalAmtQuery(tableName, subQryAlias, innerSubQryAls, from, to)
		queryStr = " (select #{innerSubQryAls}.parent_id, #{innerSubQryAls}.parent_type," + 
			" #{innerSubQryAls}.#{innerSubQryAls}_month, #{innerSubQryAls}.#{innerSubQryAls}_year," +
			" sum (#{innerSubQryAls}.amount) as #{innerSubQryAls}_amount from" +
			" (select ii.amount, ii.#{tableName}_id, i.#{tableName}_date,i.parent_type," + 
			" i.parent_id, date_part('month', #{tableName}_date) as #{innerSubQryAls}_month," + " date_part('year', #{tableName}_date) as #{innerSubQryAls}_year" + 
			" from wk_#{tableName}_items ii left join wk_#{tableName}s i" + 
			" on i.id = ii.#{tableName}_id" +
			" where i.#{tableName}_date between '#{from}' and '#{to}') as #{innerSubQryAls}" + 
			" group by #{innerSubQryAls}.parent_type, #{innerSubQryAls}.parent_id, #{innerSubQryAls}.#{innerSubQryAls}_year, #{innerSubQryAls}.#{innerSubQryAls}_month) as #{subQryAlias} "
		queryStr
	end
	
	def getPrvBalQryStr(tableName, dateVal, subQryAlias)
		queryStr = " (select sum(pii.amount) prv_#{tableName}_amount," + 
			" pvi.parent_type,pvi.parent_id from wk_#{tableName}_items pii" + 
			" left join wk_#{tableName}s pvi on pvi.id = pii.#{tableName}_id" +
			" where pvi.#{tableName}_date < '#{dateVal}'" +
			" group by pvi.parent_type,pvi.parent_id) #{subQryAlias}" +
			" on (#{subQryAlias}.parent_type = coalesce(idt.parent_type,pdt.parent_type)" +
			" and #{subQryAlias}.parent_id = coalesce(idt.parent_id,pdt.parent_id)) "
		queryStr
	end
	
	def getInBtwMonthsArr(from,to)
		inBtwMnthArr = Array.new
		yearDiff = to.year - from.year
		monthDiff = to.month - from.month
		fromMonth =  from.month
		fromYear = from.year
		totalNumOfMnth = (yearDiff * 12) + monthDiff
		for count in 0 .. totalNumOfMnth
			monthVal = (fromMonth + count)%12 == 0 ? 12 : (fromMonth + count)%12
			yearVal = fromYear + ((fromMonth + count)/12)
			yearVal = yearVal - 1 if monthVal == 12
			inBtwMnthArr << [yearVal, monthVal]
		end
		inBtwMnthArr
	end
	
	def getAccountContactSql
		parentSql = ""
		if ActiveRecord::Base.connection.adapter_name == 'Mysql2'
			parentSql = "COLLATE utf8_unicode_ci"
		end
		sqlStr = "select 'WkAccount' #{parentSql} as parent_type, id as parent_id from wk_accounts where account_type = 'A' union select 'WkCrmContact' #{parentSql} as parent_type, id as parent_id from wk_crm_contacts where contact_type in ('C', 'RA')"
		sqlStr
	end
	
	def getMainLocation
		allLocation = WkLocation.all
		mainLocation = allLocation.where(:is_main => true)
		allLocation = mainLocation unless mainLocation.blank?
		allLocation = allLocation.blank? ? "" : allLocation.first.name
		allLocation
	end
	
	def getAddress	
		address_list = WkAddress.joins("RIGHT JOIN wk_locations ON wk_addresses.id = wk_locations.address_id")
		mainAddress = address_list.where("wk_locations.is_main = true")
		address_list = mainAddress unless mainAddress.blank?
		address_list = (address_list.blank? || address_list.first.id.blank?) ? "" : address_list.first.fullAddress
		address_list
	end

	def form_salaries_hash(payrollAmount, userId)

		usersDetails = User.where("id IN (#{userId})")
		salaryComponents = WkSalaryComponents.all
		basic_Total = nil
		allowance_total = nil
		deduction_total = nil
		@payrollEntries = Hash.new

		payrollAmount.each do |payroll|
			key = payroll[:user_id].to_s + "_" + payroll[:salary_date].strftime("%m").to_i.to_s + "_" + payroll[:salary_date].strftime("%Y").to_s + "_" + payroll[:project_id].to_s
			
			if @payrollEntries[key].blank?
				@payrollEntries[key] = {:projId => payroll[:project_id], :uID => payroll[:user_id], :firstname => nil, :lastname => nil, :salDate => payroll[:salary_date], :BT => 0, :AT => 0, :DT => 0, :currency => nil, :details => {:b => [], :a => [], :d => []}}
			end

			usersDetails.each do |user|
				if payroll[:user_id] == user.id
					@payrollEntries[key][:firstname] = user.firstname
					@payrollEntries[key][:lastname] = user.lastname
				end
			end
			salaryComponents.each do |s_cmpt|
				if payroll[:component_id] == s_cmpt.id
					@payrollEntries[key][:currency] = payroll[:currency]
					case s_cmpt.component_type
					when "b"
						@payrollEntries[key][:BT] = @payrollEntries[key][:BT].to_i + payroll[:amount].to_i
						@payrollEntries[key][:details][:b] << [s_cmpt.name, payroll[:amount].to_i, payroll[:currency]]
					when "a"
						@payrollEntries[key][:AT] = @payrollEntries[key][:AT].to_i + payroll[:amount].to_i
						@payrollEntries[key][:details][:a] << [s_cmpt.name, payroll[:amount].to_i, payroll[:currency]]
					when "d"
						@payrollEntries[key][:DT] = @payrollEntries[key][:DT] + payroll[:amount].to_i
						@payrollEntries[key][:details][:d] << [s_cmpt.name, payroll[:amount].to_i, payroll[:currency]]
					end
				end
			end
		end
	end
end
