module WkattendanceHelper	
	include WktimeHelper
	require 'csv' 
	#Copied from UserHelper
	def users_status_options_for_select(selected)
		user_count_by_status = User.group('status').count.to_hash
		options_for_select([[l(:label_all), ''],
                        ["#{l(:status_active)} (#{user_count_by_status[1].to_i})", '1'],
                        ["#{l(:status_registered)} (#{user_count_by_status[2].to_i})", '2'],
                        ["#{l(:status_locked)} (#{user_count_by_status[3].to_i})", '3']], selected.to_s)
	end
	
	def getSettingCfId(settingId)
		cfId = Setting.plugin_redmine_wktime[settingId].blank? ? 0 : Setting.plugin_redmine_wktime[settingId].to_i
		cfId
	end
	
	def getLeaveIssueIds
		issueIds = ''
		if(Setting.plugin_redmine_wktime['wktime_leave'].blank?)
			issueIds = '-1'
		else
			Setting.plugin_redmine_wktime['wktime_leave'].each do |element|
				if issueIds!=''
					issueIds = issueIds +','
				end
			  listboxArr = element.split('|')
			  issueIds = issueIds + listboxArr[0]
			end
		end	
		issueIds
	end
	
	def populateWkUserLeaves		
		leavesInfo = Setting.plugin_redmine_wktime['wktime_leave']
		leaveAccrual = Hash.new
		leaveAccAfter = Hash.new
		resetMonth = Hash.new
		strIssueIds = ""
		currentMonthStart = Date.civil(Date.today.year, Date.today.month, 1)
		if !leavesInfo.blank?
			leavesInfo.each do |leave|
				issue_id = leave.split('|')[0].strip
				strIssueIds = strIssueIds.blank? ? (strIssueIds + issue_id) : (strIssueIds + "," + issue_id)
				leaveAccrual[issue_id] = leave.split('|')[1].blank? ? 0 : leave.split('|')[1].strip
				leaveAccAfter[issue_id] = leave.split('|')[2].blank? ? 0 : leave.split('|')[2].strip
				resetMonth[issue_id] = leave.split('|')[3].blank? ? 0 : leave.split('|')[3].strip
			end
		end
		
		deleteWkUserLeaves(nil, currentMonthStart - 1)
		
		joinDateCFID = !Setting.plugin_redmine_wktime['wktime_attn_join_date_cf'].blank? ? Setting.plugin_redmine_wktime['wktime_attn_join_date_cf'].to_i : 0
		
		if !strIssueIds.blank?		
			from = currentMonthStart << 1
			to = (from >> 1) - 1
			
			prev_mon_from = from << 1
			prev_mon_to = (prev_mon_from >> 1) - 1
			
			defWorkTime = !Setting.plugin_redmine_wktime['wktime_default_work_time'].blank? ? Setting.plugin_redmine_wktime['wktime_default_work_time'].to_i : 8			
			
			qryStr = "select v2.id, v1.user_id, v1.created_on, v1.issue_id, v2.hours, ul.balance, " +
					"ul.accrual_on, ul.used, ul.accrual, v3.spent_hours, c.value as join_date " +
					"from (select u.id as user_id, i.issue_id, u.status, u.type, u.created_on from users u , " +
					"(select id as issue_id from issues where id in (#{strIssueIds})) i) v1 " +
					"left join (select max(id) as id, user_id, issue_id, sum(hours) as hours from time_entries " +
					"where spent_on between '#{from}' and '#{to}' group by user_id, issue_id) v2 " +
					"on v2.user_id = v1.user_id and v2.issue_id = v1.issue_id " +
					"left join (select user_id, sum(hours) as spent_hours from wk_attendances " +
					"where start_time between '#{from}' and '#{to}' " +
					"group by user_id) v3 on v3.user_id = v1.user_id " +
					"left join wk_user_leaves ul on ul.user_id = v1.user_id and ul.issue_id = v1.issue_id " +
					"and ul.accrual_on between '#{prev_mon_from}' and '#{prev_mon_to}' " +
					"left join custom_values c on c.customized_id = v1.user_id and c.custom_field_id = #{joinDateCFID} " +
					"where v1.status = 1 and v1.type = 'User'"
					
			entries = TimeEntry.find_by_sql(qryStr)		
			if !entries.blank?				
				entries.each do |entry|				
					userJoinDate = entry.join_date.blank? ? entry.created_on.to_date : entry.join_date.to_date
					yearDiff = ((Date.today - userJoinDate).to_i / 365.0)
					accrualAfter = leaveAccAfter["#{entry.issue_id}"].to_f						
					includeAccrual = yearDiff >= accrualAfter ? true : false
					accrual = leaveAccrual["#{entry.issue_id}"].to_i
						
					#Accrual will be given only when the user works atleast 11 days a month
					if (entry.spent_hours.blank? || (!entry.spent_hours.blank? && entry.spent_hours < (defWorkTime * 11)) || !includeAccrual)
						accrual = 0
					end
					lastMntBalance = entry.balance.blank? ? 0 : entry.balance
					lastMntAccrual = entry.accrual.blank? ? 0 : entry.accrual
					no_of_holidays = lastMntBalance + lastMntAccrual #entry.balance.blank? ? entry.accrual : entry.balance + entry.accrual
					if !entry.used.blank? && entry.used > 0
						no_of_holidays = no_of_holidays - entry.used
					end
					#Reset					
					lastMonth = (currentMonthStart - 1).month		
					if (lastMonth == resetMonth["#{entry.issue_id}"].to_i)
						no_of_holidays = 0 if !no_of_holidays.blank? && no_of_holidays > 0
					end				
					userLeave = WkUserLeave.new
					userLeave.user_id = entry.user_id
					userLeave.issue_id = entry.issue_id
					userLeave.balance = no_of_holidays
					userLeave.accrual = accrual
					userLeave.used = entry.hours.blank? ? 0 : entry.hours
					userLeave.accrual_on = currentMonthStart - 1
					userLeave.save()
				end
			end
		end
	end
	
	def deleteWkUserLeaves(userId, accrualOn)
		if !(userId.blank? || accrualOn.blank?)
			WkUserLeave.where(user_id: userId).where(accrual_on: accrualOn).delete_all
		elsif !accrualOn.blank?
			WkUserLeave.where(accrual_on: accrualOn).delete_all
		elsif !userId.blank?
			WkUserLeave.where(user_id: userId).delete_all
		else
			WkUserLeave.delete_all
		end
	end
	
	def importAttendance(file,isAuto)
		lastAttnEntriesHash = Hash.new
		@errorHash = Hash.new
		@importCount = 0
		userCFHash = Hash.new
		custom_fields = UserCustomField.order('name')
		userIdCFHash = Hash.new
		unless custom_fields.blank?
			userCFHash = Hash[custom_fields.map { |cf| [cf.id, cf.name] }]
		end
		csv = read_file(file)
		lastAttnEntries = findLastAttnEntry(false)
		lastAttnEntries.each do |entry|
			lastAttnEntriesHash[entry.user_id] = entry
		end
		columnArr = Setting.plugin_redmine_wktime['wktime_fields_in_file']
		csv.each_with_index do |row,index|
			# rowValueHash - Have the data of the current row
			rowValueHash = Hash.new
			columnArr.each_with_index do |col,i|
				case col when "user_id"
					rowValueHash["user_id"] = row[i]
				when "start_time","end_time"
					if row_date(row[i]).is_a?(DateTime) || (row[i].blank? && col == "end_time")
						rowValueHash[col] = row_date(row[i]) 
					else
						#isValid = false
						@errorHash[index+1] = col + " " + l('activerecord.errors.messages.invalid')
					end
				when "hours"
					rowValueHash[col] = row[i].to_f
				else
					if index < 1
						cfId = col.to_i #userCFHash[col] 
						userIdCFHash = getUserIdCFHash(cfId)
					end
					if userIdCFHash[row[i]].blank?
						@errorHash[index+1] = userCFHash[col.to_i] + " " + l('activerecord.errors.messages.invalid')
					else
						rowValueHash["user_id"] = userIdCFHash[row[i]]	
					end
				end
			end
			# Check the row has any invalid entries and skip that row from import
			if @errorHash[index+1].blank?
				@importCount = @importCount + 1
				userId = rowValueHash["user_id"] #row[0].to_i
				endEntry = nil
				startEntry = getFormatedTimeEntry(rowValueHash["start_time"])
				if !rowValueHash["end_time"].blank? && (rowValueHash["end_time"] != rowValueHash["start_time"]) 
					endEntry = getFormatedTimeEntry(rowValueHash["end_time"]) 
				end
				
				if (columnArr.include? "end_time") && (columnArr.include? "start_time")
					#Get the imported records for particular user and start_time
					importedEntry = WkAttendance.where(:user_id => userId, :start_time => startEntry)
					if  importedEntry[0].blank? 
						# There is no records for the given user on the given start_time
						# Insert a new record to the database
						lastAttnEntriesHash[userId] = addNewAttendance(startEntry,endEntry,userId)
					else
						# Update the record with end Entry
						if importedEntry[0].end_time.blank? && !endEntry.blank?
							lastAttnEntriesHash[userId] = saveAttendance(importedEntry[0], startEntry, endEntry, userId, true)
						end
					end
				else
					# Get the imported records for particular user and entry_time
					# Skip the records which is already inserted by check importedEntry[0].blank? 
					importedEntry = WkAttendance.where("user_id = ? AND (start_time = ? OR end_time = ?)", userId, startEntry, startEntry)
					if importedEntry[0].blank? 
						lastAttnEntriesHash[userId] = saveAttendance(lastAttnEntriesHash[userId], startEntry, endEntry, userId, false)	
					end
				end
			end
		end
		if isAuto
			Rails.logger.info("====== File Name = #{File.basename file}=========")
			if  @importCount > 0
				Rails.logger.info("==== #{l(:notice_import_finished, :count => @importCount)} ====")
			end
			if !@errorHash.blank? && @errorHash.count > 0
				Rails.logger.info("==== #{l(:notice_import_finished_with_errors, :count => @errorHash.count, :total => (@errorHash.count + @importCount))} ====")
				Rails.logger.info("===============================================================")
				Rails.logger.info("       Row           ||        Message            ")
				Rails.logger.info("===============================================================")
				@errorHash.each do |item|
					Rails.logger.info("    #{item[0]}           || #{simple_format_without_paragraph item[1]}")
					Rails.logger.info("---------------------------------------------------------------")
				end
				Rails.logger.info("===============================================================")
			end
		end
		return @errorHash.blank? || @errorHash.count < 0
	end
	
	def read_file(file)
		csv_text = File.read(file)
		hasHeaders = (Setting.plugin_redmine_wktime['wktime_import_file_headers'].blank? || Setting.plugin_redmine_wktime['wktime_import_file_headers'].to_i == 0) ? false : true
		csv_options = {:headers => hasHeaders}
		csv_options[:encoding] = Setting.plugin_redmine_wktime['wktime_field_encoding']#'UTF-8'
		separator = Setting.plugin_redmine_wktime['wktime_field_separator']#','
		csv_options[:col_sep] = separator if separator.size == 1
		wrapper = Setting.plugin_redmine_wktime['wktime_field_wrapper']#'"'
		csv_options[:quote_char] = wrapper if wrapper.size == 1
		csv = CSV.parse(csv_text, csv_options)
		csv
	end
	
	def getFormatedTimeEntry(entryDateTime)
		entryDateTime = entryDateTime.change(:offset => Time.current.localtime.strftime("%:z"))
		entryTime = Time.parse("#{entryDateTime.utc.to_date.to_s} #{entryDateTime.utc.to_time.to_s} ").localtime
		entryTime
	end
	
	def getUserIdCFHash(cfId)
		cfValHash = Hash.new
		cfValue = CustomValue.where("custom_field_id = #{cfId}")
		unless cfValue.blank?
			#cfs = custom_fields.collect {|cf| userCFHash[cf.name] = cf.id }
			cfValHash = Hash[cfValue.map { |cfv| [cfv.value, cfv.customized_id] }]
		end
		cfValHash
	end
	
	def row_date(dateTimeStr)
			format = Setting.plugin_redmine_wktime['wktime_field_datetime']#"%Y-%m-%d %T"
			DateTime.strptime(dateTimeStr, format) rescue dateTimeStr
	end
	
	def addNewAttendance(startEntry,endEntry,userId) 
		wkattendance = WkAttendance.new
		wkattendance.start_time = startEntry
		wkattendance.end_time = endEntry
		wkattendance.hours = computeWorkedHours(wkattendance.start_time,wkattendance.end_time, true) unless endEntry.blank?
		wkattendance.user_id = userId
		wkattendance.save()
		wkattendance
	end

	def saveAttendance(attnObj, startTime, endTime, userId, hasStartEnd)
		wkattendance = nil
		if(!attnObj.blank? && ((attnObj.end_time.blank? && attnObj.start_time > (startTime -  1.day) )|| hasStartEnd))
			if !hasStartEnd
				entrydate = attnObj.start_time
				start_local = entrydate.localtime
				if ((startTime.to_date) != attnObj.start_time.to_date)
					endtime = start_local.change({ hour: "23:59".to_time.strftime("%H"), min: "23:59".to_time.strftime("%M"), sec: '59' })
					nextDayStart = Time.parse("#{startTime.to_date.to_s} 00:00:00 ").localtime.to_s
					wkattendance = addNewAttendance(nextDayStart,startTime,userId)
				else
					endtime = start_local.change({ hour: startTime.localtime.strftime("%H"), min:startTime.localtime.strftime("%M"), sec: startTime.localtime.strftime("%S") })
				end
			else
				endtime = endTime
			end
			
			attnObj.end_time = endtime
			attnObj.hours = computeWorkedHours(attnObj.start_time,attnObj.end_time, true)
			attnObj.save()
			wkattendance = attnObj if wkattendance.blank?
		else
			wkattendance = addNewAttendance(startTime,endTime,userId)
		end
		wkattendance
	end
	
	def calcSchdulerInterval
		interval = (Setting.plugin_redmine_wktime['wktime_auto_import_time_hr'].to_i*60) + (Setting.plugin_redmine_wktime['wktime_auto_import_time_min'].to_i)
		intervalMin = interval>0 ? interval.to_s + 'm' : '60m'
		intervalMin
	end

end
