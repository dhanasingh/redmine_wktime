module WkreportHelper	
	include WktimeHelper

	def options_for_period_select(value)
		options_for_select([
							[l(:label_this_week), 'current_week'],
							[l(:label_last_week), 'last_week'],
							[l(:label_this_month), 'current_month'],
							[l(:label_last_month), 'last_month']],
							value.blank? ? 'current_week' : value)
	end	

	def options_for_report_select(selectedRpt)
		options_for_select([
			[l(:label_wk_attendance), 'attendance_report'], 
			[l(:label_time_entry_plural), 'spent_time_report'], 
			[l(:label_wk_timesheet), 'time_report'], 			
			[l(:label_wk_expensesheet), 'expense_report'],			
			[l(:label_payroll_report), 'payroll_report'],
			[l(:label_wk_payslip), 'payslip_report']], selectedRpt)
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

end
