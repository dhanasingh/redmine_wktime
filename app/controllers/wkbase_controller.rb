class WkbaseController < ApplicationController
unloadable
include WkattendanceHelper
  
	def updateClockInOut
		lastAttnEntries = findLastAttnEntry(true)
		if !lastAttnEntries.blank?
			@lastAttnEntry = lastAttnEntries[0]
		end	
		currentDate = (DateTime.parse params[:startdate])
		entryTime  =  Time.parse("#{currentDate.to_date.to_s} #{currentDate.utc.to_time.to_s} ").localtime
		@lastAttnEntry = saveAttendance(@lastAttnEntry, entryTime, nil, User.current.id, false)
		ret = 'done'
		respond_to do |format|
			format.text  { render :text => ret }
		end
	end
end
