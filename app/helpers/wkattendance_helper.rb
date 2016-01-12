module WkattendanceHelper	
	include WktimeHelper
	
	def time_expense_tabs
		if isAccountUser
			tabs = [
					{:name => 'wktime', :partial => 'wktime/tab_content', :label => :label_wktime},
					{:name => 'wkexpense', :partial => 'wktime/tab_content', :label => :label_wkexpense},
					{:name => 'wkattendance', :partial => 'wktime/tab_content', :label => :label_wk_attendance},
					{:name => 'wkattnreport', :partial => 'wktime/tab_content', :label => :label_report_plural}
				   ]
		else
			tabs = [
					{:name => 'wktime', :partial => 'wktime/tab_content', :label => :label_wktime},
					{:name => 'wkexpense', :partial => 'wktime/tab_content', :label => :label_wkexpense},
					{:name => 'wkattendance', :partial => 'wktime/tab_content', :label => :label_wk_attendance}
				   ]
		end
	end	

	def options_for_period_select(value)
		options_for_select([
							[l(:label_this_month), 'current_month'],
							[l(:label_last_month), 'last_month']],
							value.blank? ? 'current_month' : value)
	end	

	def options_for_report_select(value)
		options_for_select([
							[l(:label_wk_attendance), 'attendance_report'],
							[l(:label_wk_time), 'wk_time']],
							value.blank? ? 'attendance_report' : value)
	end	

end
