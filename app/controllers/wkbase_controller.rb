class WkbaseController < ApplicationController
  unloadable
  
	def findLastAttnEntry
		WkAttendance.find_by_sql("select a.* from wk_attendances a inner join ( select max(start_time) as start_time,user_id from wk_attendances where user_id = #{User.current.id} group by user_id ) vw on a.start_time = vw.start_time and a.user_id = vw.user_id order by a.start_time ")
	end	
	
	def updateClockInOut
		if !findLastAttnEntry.blank?
			@lastAttnEntry = findLastAttnEntry[0]
		end	
		currentDate = (DateTime.parse params[:startdate])
		if params[:str] != "start" #&& isAccountUser
			entrydate = @lastAttnEntry.start_time
			start_local = entrydate.localtime
			if ((Date.parse params[:startdate]) != @lastAttnEntry.start_time.to_date)
				endtime = start_local.change({ hour: "23:59".to_time.strftime("%H"), min: "23:59".to_time.strftime("%M"), sec: '59' })
				addNewAttendance
			else
				endtime = start_local.change({ hour: currentDate.to_time.strftime("%H"), min:currentDate.to_time.strftime("%M"), sec: currentDate.to_time.strftime("%S") })
			end
			@lastAttnEntry.end_time = endtime
			@lastAttnEntry.hours = computeWorkedHours(@lastAttnEntry.start_time,@lastAttnEntry.end_time, true)
			@lastAttnEntry.save()
		else
			addNewAttendance
		end	
		ret = 'done'
		respond_to do |format|
			format.text  { render :text => ret }
		end
	end
	
	def addNewAttendance
		wkattendance = WkAttendance.new
		currentDate = DateTime.parse params[:startdate]
		entrydate =  Date.parse params[:startdate]
		wkattendance.user_id = params[:user_id].to_i 
		if params[:str] != "start"		
			wkattendance.start_time = Time.parse("#{entrydate.to_s} 00:00:00 ").localtime.to_s
			wkattendance.end_time = currentDate
			endtime = currentDate
			wkattendance.hours = computeWorkedHours(wkattendance.start_time,wkattendance.end_time, true) 
		else
			wkattendance.start_time = currentDate
			endtime = nil
		end
		wkattendance.user_id = User.current.id
		wkattendance.save()
	end
	
	def computeWorkedHours(startTime,endTime, ishours)
		currentEntryDate = startTime.localtime
		workedHours = endTime-startTime
		if !Setting.plugin_redmine_wktime['wktime_break_time'].blank?
			Setting.plugin_redmine_wktime['wktime_break_time'].each_with_index do |element,index|
			  listboxArr = element.split('|')
			  breakStart = currentEntryDate.change({ hour: listboxArr[0], min:listboxArr[1], sec: '00' })
			  breakEnd = currentEntryDate.change({ hour: listboxArr[2], min:listboxArr[3], sec: '00' })
			  if(!(startTime>breakEnd || endTime < breakStart))
				if startTime < breakStart
					if endTime < breakEnd
						workedHours = workedHours - (endTime-breakStart)
					else
						workedHours = workedHours - (breakEnd-breakStart)
					end
				else
					if endTime > breakEnd
						workedHours = workedHours - (breakEnd-startTime)
					else
						workedHours = nil
					end
				end
			  end
			end
		end
		if ishours
			workedHours = (workedHours/1.hour).round(2) unless workedHours.blank?
		end
		workedHours
	end
	
	def totalhours
		dateStr = getConvertDateStr('start_time')
		(WkAttendance.where("user_id = #{User.current.id} and #{dateStr} = '#{Time.now.strftime("%Y-%m-%d")}'").sum(:hours)).round(2)
	end
end
