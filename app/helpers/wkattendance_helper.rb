module WkattendanceHelper	
	include WktimeHelper
	
	def time_expense_tabs
		tabs = [
				{:name => 'wktime', :partial => 'wktime/tab_content', :label => :label_wktime},
				{:name => 'wkexpense', :partial => 'wktime/tab_content', :label => :label_wkexpense},
				{:name => 'wkattendance', :partial => 'wktime/tab_content', :label => :label_wk_attendance},
				{:name => 'wkattnreport', :partial => 'wktime/tab_content', :label => :label_report_plural}
			   ]
	end	

	def options_for_period_select
		options_for_select([
							[l(:label_this_month), 'current_month'],
							[l(:label_last_month), 'last_month']],
							'current_month')
	end	

	def options_for_report_select
		options_for_select([
							[l(:label_wk_attendance), 'attendance_report']],
							'attendance_report')
	end	

end
