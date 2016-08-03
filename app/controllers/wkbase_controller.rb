class WkbaseController < ApplicationController
  unloadable
  
	def updateClockInOut
		lastAttnEntries = findLastAttnEntry(true)
		if !lastAttnEntries.blank?
			@lastAttnEntry = lastAttnEntries[0]
		end	
		currentDate = (DateTime.parse params[:startdate])
		entryTime  =  Time.parse("#{currentDate.utc.to_date.to_s} #{currentDate.utc.to_time.to_s} ").localtime
		@lastAttnEntry = saveAttendance(@lastAttnEntry, entryTime, nil, User.current.id, false)
		ret = 'done'
		respond_to do |format|
			format.text  { render :text => ret }
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
end
