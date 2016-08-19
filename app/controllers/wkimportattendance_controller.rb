class WkimportattendanceController < WkattendanceController	
unloadable 

include WkimportattendanceHelper

before_filter :require_login
require 'csv'
	
	def new
	end
	
	def show
		file = params[:file]
		unless file.blank?
			filePath = file.path 
			begin
				isSuccess = importAttendance(filePath, false)
				#redirect_to :action => 'show'
			rescue Exception => e
				@errorMsg = "Import failed: #{e.message}"
				flash[:error] = @errorMsg
				redirect_to :action => 'new'
			end
		else
			redirect_to :action => 'new'
		end
	end
	
end
