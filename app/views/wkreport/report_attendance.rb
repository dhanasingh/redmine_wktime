module ReportAttendance
  include WkreportHelper
	require 'rbpdf'

  def calcReportData(user_id, group_id, projId, from, to)
		unless from.blank?
			from = Date.civil(from.year,from.month, 1) 
			to = (from >> 1) - 1 
		end
    attendance = {}
		dateStr = getConvertDateStr('start_time')
		sqlStr = ""
		userSqlStr = getUserQueryStr(group_id,user_id, from)
		leaveSql = "select u.id as user_id, gu.group_id, i.id as issue_id, l.balance, l.accrual, l.used, l.accrual_on," + 
		" lm.balance + lm.accrual - lm.used as open_bal from users u" + 
		" left join groups_users gu on (gu.user_id = u.id and gu.group_id = #{group_id})" +
		" cross join (select id from issues where id in (#{getReportLeaveIssueIds}) " + get_comp_cond('issues') + ") i" + 
		" left join (#{getLeaveQueryStr(from,to)}) l on l.user_id = u.id and l.issue_id = i.id" + get_comp_cond('l') +
		" left join (#{getLeaveQueryStr(from << 1,from - 1)}) lm on lm.user_id = u.id and i.id = lm.issue_id"
		if group_id.to_i > 0 && user_id.to_i < 1
			leaveSql = leaveSql + " Where gu.group_id is not null" + get_comp_cond('u')
		elsif user_id.to_i > 0
			leaveSql = leaveSql + " Where u.id = #{user_id}" + get_comp_cond('u')
		end
		if validateERPPermission('A_TE_PRVLG') || User.current.admin?
			leave_entry = TimeEntry.where("issue_id in (#{getLeaveIssueIds}) and spent_on between '#{from}' and '#{to}'")
			if getType == 'spent_time'
				sqlStr = "select user_id,spent_on,sum(hours) as hours from time_entries where issue_id not in (#{getLeaveIssueIds}) and spent_on between '#{from}' and '#{to}' " + get_comp_cond('time_entries') + " group by user_id,spent_on"
			else
				sqlStr = "select user_id,#{dateStr} as spent_on,sum(hours) as hours from wk_attendances where #{dateStr} between '#{from}' and '#{to}' " + get_comp_cond('wk_attendances') + " group by user_id,#{dateStr}"
			end
		else
			leave_entry = TimeEntry.where("issue_id in (#{getLeaveIssueIds}) and spent_on between '#{from}' and '#{to}' and user_id = #{User.current.id} " )
			if getType == 'spent_time'
				sqlStr = "select user_id,spent_on,sum(hours) as hours from time_entries where issue_id not in (#{getLeaveIssueIds}) and spent_on between '#{from}' and '#{to}' and user_id = #{User.current.id} " + get_comp_cond('time_entries') + " group by user_id,spent_on"
			else
				sqlStr = "select user_id,#{dateStr} as spent_on,sum(hours) as hours from wk_attendances where #{dateStr} between '#{from}' and '#{to}' and user_id = #{User.current.id} " + get_comp_cond('wk_attendances') + " group by user_id,#{dateStr}"
			end
		end
		@userlist = WkUserLeave.find_by_sql(userSqlStr + " order by u.created_on " ) 
		leave_data = WkUserLeave.find_by_sql(leaveSql)
		daily_entries = WkAttendance.find_by_sql(sqlStr)
		@attendance_entries = Hash.new
		if !leave_data.blank?
			leave_data.each_with_index do |entry,index|
				@attendance_entries[entry.user_id.to_s + '_' + entry.issue_id.to_s + '_balance'] = entry.open_bal
				@attendance_entries[entry.user_id.to_s + '_' + entry.issue_id.to_s + '_used'] = entry.used
				@attendance_entries[entry.user_id.to_s + '_' + entry.issue_id.to_s + '_accrual'] = entry.accrual
			end
		end
		if !leave_entry.blank?
			leave_entry.each_with_index do |entry,index|
				@attendance_entries[entry.user_id.to_s + '_' + entry.spent_on.to_date.strftime("%d").to_i.to_s + '_leave'] = entry.issue_id
			end
		end
		if !daily_entries.blank?
			daily_entries.each_with_index do |entry,index|
				@attendance_entries[entry.user_id.to_s + '_' + entry.spent_on.to_date.strftime("%d").to_i.to_s  + '_hours'] = entry.hours.is_a?(Float) ? entry.hours.round(2) : (entry.hours.blank? ? '*' :  entry.hours)
			end
		end

		wktime_helper = Object.new.extend(WktimeHelper)
		headIssueId = []
		issue_list = Issue.order('subject')
		shortName = Hash.new
		unless issue_list.blank?
			issueslist = issue_list.collect {|issue| [issue.subject, issue.id] }
			issuehash = Hash[issue_list.map { |u| [u.id, u.subject] }]
		end
		if !wktime_helper.getLeaveSettings.blank?
			wktime_helper.getLeaveSettings.each_with_index do |element,index|
			listboxArr = element.split('|')
			if index < 3
				headIssueId[index] = listboxArr[0]
			end
			shortName[listboxArr[0].to_i] = listboxArr[4].blank? ? issuehash[listboxArr[0].to_i].first(2) : listboxArr[4]
		end
			headIssueId = headIssueId.sort_by(&:to_i)
		end
		user_data = getuserData(@userlist, @attendance_entries, headIssueId, shortName)
		attendance = {userlist: @userlist, attendance_entries: @attendance_entries, shortName: shortName, headIssueId: headIssueId, user_data: user_data, month: from.strftime("%B") , year: from.strftime("%Y")}
  end

	def getuserData(userlist, attendance_entries, headIssueId, shortName)
		user_data = {}
		userlist.each_with_index do |entry,index|
			key = entry.id.to_s
			balance1 = attendance_entries[key + '_' + headIssueId[0].to_s + '_balance']
			balance2 = attendance_entries[key + '_' + headIssueId[1].to_s + '_balance']
			balance3 = attendance_entries[key + '_' + headIssueId[2].to_s + '_balance']
			used1 = attendance_entries[key + '_' + headIssueId[0].to_s + '_used']
			used2 = attendance_entries[key + '_' + headIssueId[1].to_s + '_used']
			used3 = attendance_entries[key + '_' + headIssueId[2].to_s + '_used']
			accrual1 = attendance_entries[key + '_' + headIssueId[0].to_s + '_accrual']
			accrual2 = attendance_entries[key + '_' + headIssueId[1].to_s + '_accrual']
			accrual3 = attendance_entries[key + '_' + headIssueId[2].to_s + '_accrual']
			user_data[key] = {}
			user_data[key]['employee_id'] = entry.employee_id
			user_data[key]['name'] = entry.firstname + " " + entry.lastname
			user_data[key]['join_date'] = entry.join_date.blank? ? '' : format_date(entry.join_date.to_date)
			user_data[key]['birth_date'] = entry.birth_date.blank? ? '' : format_date(entry.birth_date.to_date)
			user_data[key]['designation'] = entry.designation
			user_data[key]['balance1'] = balance1
			user_data[key]['balance2'] = balance2
			user_data[key]['balance3'] = balance3
			user_data[key]['used1'] = used1
			user_data[key]['used2'] = used2
			user_data[key]['used3'] = used3
			user_data[key]['accrual1'] = (accrual1.blank? && used1.blank? ? '' : (balance1.blank? ? 0 : balance1) + (accrual1.blank? ? 0 : accrual1) - (used1.blank? ? 0 : used1))
			user_data[key]['accrual2'] = (accrual2.blank? && used2.blank? ? '' : (balance2.blank? ? 0 : balance2) + (accrual2.blank? ? 0 : accrual2) - (used2.blank? ? 0 : used2))
			user_data[key]['accrual3'] = (accrual3.blank? && used3.blank? ? '' : (balance3.blank? ? 0 : balance3) + (accrual3.blank? ? 0 : accrual3) - (used3.blank? ? 0 : used3))
			totalhours = 0
			user_data[key]['date'] = []
			for i in 1..31
				hour = attendance_entries[key + '_' + i.to_s + '_hours']
				leave = attendance_entries[key + '_' + i.to_s + '_leave']
				attn_entry = shortName[leave].blank? ? hour : (hour.blank? ? shortName[leave] : (hour.to_s) + "/ " + shortName[leave])
				totalhours = totalhours + (hour.blank? ? 0 : hour.to_f)
			user_data[key]['date'] << attn_entry
			end
			user_data[key]['totalhours'] = totalhours.round(2)
		end
		user_data
	end

	def getType
		return 'attendance'
	end

	def getExportData(user_id, group_id, projId, from, to)
    rptData = calcReportData(user_id, group_id, projId, from, to)
    headers = {}
    data = []
		
		headers ={sl_no: l(:label_attn_sl_no), user: l(:field_user), service_date: l(:label_date_of_entry_into_service), age: l(:label_age)+ " / " +l(:label_wk_attn_user_dob), designation: l(:label_wk_designation), balance1: l(:label_leave_beginning_of_mnth), balance2: '', balance3: '', used1: l(:label_leave_during_mnth), used2: '', used3: '', accrual1: l(:label_wk_leave)+" "+l(:wk_field_balance), accrual2: '', accrual3: ''}
		for i in 1..31
			headers.store('days_'+i.to_s, i == 1 ? l(:label_daily_workdone_inclede_ot) : '')
		end
		headers.store(:total_hrs_ot, l(:label_total_hours_ot))
		headers.store(:total_hrs, l(:label_total_hours_during_mnth))
		headers.store(:maternity_leave, l(:label_total_no_of_maternity_leave))
		headers.store(:sl_nos, l(:label_attn_sl_no))

		detailHeaders ={sl_no: '', user: '', service_date: '', age: '', designation: '', balance1: rptData[:shortName][rptData[:headIssueId][0].to_i], balance2: rptData[:shortName][rptData[:headIssueId][1].to_i], balance3: rptData[:shortName][rptData[:headIssueId][2].to_i], used1: rptData[:shortName][rptData[:headIssueId][0].to_i], used2: rptData[:shortName][rptData[:headIssueId][1].to_i], used3: rptData[:shortName][rptData[:headIssueId][2].to_i], accrual1: rptData[:shortName][rptData[:headIssueId][0].to_i], accrual2: rptData[:shortName][rptData[:headIssueId][1].to_i], accrual3: rptData[:shortName][rptData[:headIssueId][2].to_i]}
		for i in 1..31
			detailHeaders.store('days_'+i.to_s, i)
		end
		detailHeaders.store(:total_hrs_ot, '')
		detailHeaders.store(:total_hrs, '')
		detailHeaders.store(:maternity_leave, '')
		detailHeaders.store(:sl_nos, '')		
		data << detailHeaders

		rptData[:user_data].each do |key, entry|
			details =  {sl_no: entry['employee_id'], user: entry['name'], service_date: entry['join_date'], age: entry['birth_date'], designation: entry['designation'], balance1: entry['balance1'], balance2: entry['balance2'], balance3: entry['balance3'], used1: entry['used1'], used2: entry['used2'], used3: entry['used3'], accrual1: entry['accrual1'], accrual2: entry['accrual2'], accrual3: entry['accrual3']}
			for i in 1..31
				details.store('days_'+i.to_s, entry['date'][i])
			end
			details.store(:total_hrs_ot, '')
			details.store(:total_hrs, entry['totalhours'])
			details.store(:maternity_leave, '')
			details.store(:sl_nos, entry['employee_id'])
			data << details
		end
		return {data: data, headers: headers}
	end  

	def pdf_export(data)
		pdf = ITCPDF.new(current_language)
		pdf.AddPage("L", "A1")
		row_Height = 8
		page_width    = pdf.get_page_width
		left_margin   = pdf.get_original_margins['left']
		right_margin  = pdf.get_original_margins['right']
		table_width = page_width - right_margin - left_margin
		pdf.SetFontStyle('B', 10)
		pdf.RDMMultiCell(table_width, row_Height, l(:label_wk_form_q), 0)
		pdf.RDMMultiCell(table_width, row_Height, l(:label_wk_register_for_shops), 0)
		pdf.RDMCell(pdf.get_string_width(l(:label_wk_name_address)) + 2, row_Height, l(:label_wk_name_address) + ':', 0)
		pdf.SetFontStyle('', 10)
		pdf.RDMCell(pdf.get_string_width(Setting.app_title) + 2, row_Height, Setting.app_title, 0)
		pdf.SetFontStyle('B', 10)
		pdf.RDMCell(pdf.get_string_width(l(:label_month)) + 5, row_Height, l(:label_month) + ':', 0)
		pdf.SetFontStyle('', 10)
		pdf.RDMCell(20, row_Height, data[:from].strftime("%B").to_s, 0)
		pdf.SetFontStyle('B', 10)
		pdf.RDMCell(pdf.get_string_width(l(:label_year)) + 3, row_Height, l(:label_year) + ':', 0)
		pdf.SetFontStyle('', 10)
		pdf.RDMCell(25, row_Height, data[:from].strftime("%Y").to_s, 0)
    logo =data[:logo]
		if logo.present?
			pdf.Image(logo.diskfile.to_s, page_width-50, 15, 30, 25)
		end
		pdf.ln(20)
		pdf.SetFontStyle('B', 10)
		pdf.set_fill_color(230, 230, 230)
		data[:headers].each do|key, value|
			pdf.RDMMultiCell(get_col_wdith(key), 25, value.to_s, 1, 'C', 0, 0)
		end
		pdf.ln(25)
		pdf.set_fill_color(255, 255, 255)

		data[:data].each do |entry|
			entry.each do |key, value|
				pdf.RDMCell(get_col_wdith(key), row_Height, value.to_s, 1, 0, 'C', 0)
			end
			pdf.SetFontStyle('', 9)
		  pdf.ln
		end
		pdf.Output
	end

	def get_col_wdith(key)
		headers ={user: 55, service_date: 30, age: 30, designation: 35, balance1: 30, balance2: 15, balance3: 15, used1: 30, used2: 15, used3: 15, accrual1: 30, accrual2: 15, accrual3: 15, total_hrs_ot: 20, total_hrs: 30, maternity_leave: 20, 'days_1' => 25}
		width = headers[key] || 10
	end
end