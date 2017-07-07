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
		if reportName == 'report_profit_loss' || reportName == 'report_balance_sheet'
			ret = isModuleAdmin('wktime_accounting_group') || isModuleAdmin('wktime_accounting_admin')
		elsif reportName == 'report_lead_conversion' || reportName == 'report_sales_activity'
			ret = (isModuleAdmin('wktime_crm_group') || isModuleAdmin('wktime_crm_admin') ) && isChecked('wktime_enable_crm_module')
		elsif reportName == 'report_order_to_cash'
			ret = isModuleAdmin('wktime_billing_groups')
		end
		ret
	end
	
	def getUserQueryStr(group_id,user_id, from)
		queryStr = "select u.id , gu.group_id, u.firstname, u.lastname,cvt.value as termination_date, cvj.value as joining_date, " +
			"cvdob.value as date_of_birth, cveid.value as employee_id, cvdesg.value as designation, cvgender.value as gender from users u " +
			"left join groups_users gu on (gu.user_id = u.id and gu.group_id = #{group_id}) " +
			"left join custom_values cvt on (u.id = cvt.customized_id and cvt.value != '' and cvt.custom_field_id = #{getSettingCfId('wktime_attn_terminate_date_cf')} ) " +
			"left join custom_values cvj on (u.id = cvj.customized_id and cvj.custom_field_id = #{getSettingCfId('wktime_attn_join_date_cf')} ) " +
			"left join custom_values cvdob on (u.id = cvdob.customized_id and cvdob.custom_field_id = #{getSettingCfId('wktime_attn_user_dob_cf')} ) " +
			"left join custom_values cveid on (u.id = cveid.customized_id and cveid.custom_field_id = #{getSettingCfId('wktime_attn_employee_id_cf')} ) " +
			"left join custom_values cvdesg on (u.id = cvdesg.customized_id and cvdesg.custom_field_id = #{getSettingCfId('wktime_attn_designation_cf')} ) " +
			"left join custom_values cvgender on (u.id = cvgender.customized_id and cvgender.custom_field_id = #{getSettingCfId('wktime_gender_cf')} ) " +
			"where u.type = 'User' and (#{getConvertDateStr('cvt.value')} >= '#{from}' or (u.status = #{User::STATUS_ACTIVE} and cvt.value is null))"
		if group_id.to_i > 0 && user_id.to_i < 1
			queryStr = queryStr + " and gu.group_id is not null"
		elsif user_id.to_i > 0
			queryStr = queryStr + " and u.id = #{user_id}"
		end
		
		if !(isAccountUser || User.current.admin?)
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
		sqlStr = "select 'WkAccount' #{parentSql} as parent_type, id as parent_id from wk_accounts where account_type = 'A' union select 'WkCrmContact' #{parentSql} as parent_type, id as parent_id from wk_crm_contacts where contact_type = 'C'"
		sqlStr
	end

end
