class WkimportattendanceController < WkattendanceController	
unloadable 

include WkimportattendanceHelper

before_filter :require_login
before_filter :check_ta_admin_and_redirect, :only => [:new]
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
	
	def check_ta_admin_and_redirect
		unless isAccountUser
			render_403
			return false
		end
	end
	
end
