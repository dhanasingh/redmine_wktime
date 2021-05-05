module ReportAttendance
  include WkreportHelper

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
		" cross join (select id from issues where id in (#{getReportLeaveIssueIds})) i" + 
		" left join (#{getLeaveQueryStr(from,to)}) l on l.user_id = u.id and l.issue_id = i.id" + 
		" left join (#{getLeaveQueryStr(from << 1,from - 1)}) lm on lm.user_id = u.id and i.id = lm.issue_id"
		if group_id.to_i > 0 && user_id.to_i < 1
			leaveSql = leaveSql + " Where gu.group_id is not null"
		elsif user_id.to_i > 0
			leaveSql = leaveSql + " Where u.id = #{user_id}"
		end
		if validateERPPermission('A_TE_PRVLG') || User.current.admin?
			leave_entry = TimeEntry.where("issue_id in (#{getLeaveIssueIds}) and spent_on between '#{from}' and '#{to}'")
			if @useSpentTime
				sqlStr = "select user_id,spent_on,sum(hours) as hours from time_entries where issue_id not in (#{getLeaveIssueIds}) and spent_on between '#{from}' and '#{to}' group by user_id,spent_on"
			else
				sqlStr = "select user_id,#{dateStr} as spent_on,sum(hours) as hours from wk_attendances where #{dateStr} between '#{from}' and '#{to}' group by user_id,#{dateStr}"
			end
		else
			leave_entry = TimeEntry.where("issue_id in (#{getLeaveIssueIds}) and spent_on between '#{from}' and '#{to}' and user_id = #{User.current.id} " )
			if @useSpentTime
				sqlStr = "select user_id,spent_on,sum(hours) as hours from time_entries where issue_id not in (#{getLeaveIssueIds}) and spent_on between '#{from}' and '#{to}' and user_id = #{User.current.id} group by user_id,spent_on"
			else
				sqlStr = "select user_id,#{dateStr} as spent_on,sum(hours) as hours from wk_attendances where #{dateStr} between '#{from}' and '#{to}' and user_id = #{User.current.id} group by user_id,#{dateStr}"
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
		if !Setting.plugin_redmine_wktime['wktime_leave'].blank?
			Setting.plugin_redmine_wktime['wktime_leave'].each_with_index do |element,index|
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
			user_data[key]['totalhours'] = totalhours
		end
		user_data
	end

	def reportType(spent_time)
		@useSpentTime = spent_time
	end
end