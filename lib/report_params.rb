module WkreportControllerPatch2
	def self.included(base)
		base.send(:include)
		
		base.class_eval do
			def report_params
				@report_params = [
					['attendance_report', 'Attendance', 'wkreport', 'reportattn'],
					['time_report', 'Timesheet', 'wktime', 'time_rpt'],
					['expense_report', 'Expensesheet', 'wkexpense', 'time_rpt']		
				]
			end
		end
	end
end

#['attendance_report', l(:label_wk_attendance), 'wkreport', 'reportattn'],
#['time_report', l(:label_wk_timesheet), 'wktime', 'time_rpt'],
#['expense_report', l(:label_wk_expensesheet), 'wkexpense', 'time_rpt']	

#@report_params = [
					#[report_name, description, controller_name, method_name],
					#['attendance_report', 'Attendance', 'wkreport', 'reportattn'],
					#['time_report', 'Timesheet', 'wktime', 'time_rpt'],
					['expense_report', 'Expensesheet', 'wkexpense', 'time_rpt']				
				#]