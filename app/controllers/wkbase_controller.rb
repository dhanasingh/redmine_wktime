class WkbaseController < ApplicationController
  unloadable
  
	
	
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
end
