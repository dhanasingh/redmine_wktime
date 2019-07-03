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
	
	def populateWkUserLeaves(processDt)		
		leavesInfo = Setting.plugin_redmine_wktime['wktime_leave']
		leaveAccrual = Hash.new
		accrualMultiplier = Hash.new
		leaveAccAfter = Hash.new
		resetMonth = Hash.new
		strIssueIds = ""
		processDate = processDt #params[:fromdate].to_s.to_date
		currentMonthStart = Date.civil(processDate.year, processDate.month, 1)
		if !leavesInfo.blank?
			leavesInfo.each do |leave|
				issue_id = leave.split('|')[0].strip
				strIssueIds = strIssueIds.blank? ? (strIssueIds + issue_id) : (strIssueIds + "," + issue_id)
				leaveAccrual[issue_id] = leave.split('|')[1].blank? ? 0 : leave.split('|')[1].strip
				leaveAccAfter[issue_id] = leave.split('|')[2].blank? ? 0 : leave.split('|')[2].strip
				resetMonth[issue_id] = leave.split('|')[3].blank? ? 0 : leave.split('|')[3].strip
				accrualMultiplier[issue_id] = leave.split('|')[5].blank? ? 1 : leave.split('|')[5].strip
			end
		end
		
		deleteWkUserLeaves(nil, currentMonthStart - 1)
		
		if !strIssueIds.blank?		
			from = currentMonthStart << 1
			to = (from >> 1) - 1
			
			prev_mon_from = from << 1
			prev_mon_to = (prev_mon_from >> 1) - 1
			
			defWorkTime = !Setting.plugin_redmine_wktime['wktime_default_work_time'].blank? ? Setting.plugin_redmine_wktime['wktime_default_work_time'].to_i : 8			
			
			qryStr = "select v2.id, v1.user_id, v1.created_on, v1.issue_id, v2.hours, ul.balance, " +
					"ul.accrual_on, ul.used, ul.accrual, v3.spent_hours, wu.join_date " +
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
					"left join wk_users wu on wu.user_id = v1.user_id " +
					"where v1.status = 1 and v1.type = 'User'"
					
			entries = TimeEntry.find_by_sql(qryStr)		
			if !entries.blank?				
				entries.each do |entry|				
					userJoinDate = entry.join_date.blank? ? entry.created_on.to_date : entry.join_date.to_date
					yearDiff = (((currentMonthStart - 1) - userJoinDate).to_i / 365.0)
					accrualAfter = leaveAccAfter["#{entry.issue_id}"].to_f						
					includeAccrual = yearDiff >= accrualAfter ? true : false
					accrual = leaveAccrual["#{entry.issue_id}"].to_f
					multiplier = accrualMultiplier["#{entry.issue_id}"].to_f
						
					#Accrual will be given only when the user works atleast 11 days a month
					minWorkingDays = Setting.plugin_redmine_wktime['wktime_minimum_working_days_for_accrual']
					minWorkingDays = minWorkingDays.blank? ? 0 : minWorkingDays.to_f
					if ((entry.spent_hours.blank? && minWorkingDays>0) || (!entry.spent_hours.blank? && entry.spent_hours < (defWorkTime * minWorkingDays)) || !includeAccrual)
						accrual = 0
					end
					lastMntBalance = entry.balance.blank? ? 0 : entry.balance
					lastMntAccrual = entry.accrual.blank? ? 0 : entry.accrual
					no_of_holidays = lastMntBalance + lastMntAccrual #entry.balance.blank? ? entry.accrual : entry.balance + entry.accrual
					if !entry.used.blank? && entry.used > 0
						no_of_holidays = no_of_holidays - (entry.used * multiplier)
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
	
	def convertHrTodays(hours)
		defWorkTime = !Setting.plugin_redmine_wktime['wktime_default_work_time'].blank? ? Setting.plugin_redmine_wktime['wktime_default_work_time'].to_i : 8
		noOfDays = (hours/defWorkTime).round(2).round unless hours.blank?
		noOfDays
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
		if(!attnObj.blank? && ((attnObj.end_time.blank? && ((startTime - attnObj.start_time.localtime)/3600) < 24 && ((startTime - attnObj.start_time.localtime)/3600) > 0 )|| hasStartEnd))
			if !hasStartEnd
				entrydate = attnObj.start_time
				start_local = entrydate.localtime
				if ((startTime.localtime.to_date) != attnObj.start_time.localtime.to_date)
					 endtime = start_local.change({ hour: "23:59".to_time.strftime("%H").to_i, min: "23:59".to_time.strftime("%M").to_i, sec: 59 })
					nextDayStart = Time.parse("#{startTime.to_date.to_s} 00:00:00 ").localtime.to_s
					wkattendance = addNewAttendance(nextDayStart,startTime,userId)
				else
					endtime = start_local.change({ hour: startTime.localtime.strftime("%H").to_i, min:startTime.localtime.strftime("%M").to_i, sec: startTime.localtime.strftime("%S").to_i })
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
		
	def getWorkedHours(userId,fromDate,toDate)
		workedHours = TimeEntry.where("user_id = #{userId} and spent_on between '#{fromDate}' and '#{toDate}' and issue_id not in (#{getLeaveIssueIds})").sum(:hours)
		workedHours
	end
	
	def getLeaveQueryStr(from,to)
		queryStr = "select * from wk_user_leaves WHERE issue_id in (#{getLeaveIssueIds}) and accrual_on between '#{from}' and '#{to}'"
		if !(validateERPPermission('A_TE_PRVLG') || User.current.admin?)
			queryStr = queryStr + " and user_id = #{User.current.id} "
		end
		queryStr
	end

end
