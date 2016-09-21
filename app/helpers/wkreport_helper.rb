module WkreportHelper	
	include WktimeHelper

	def options_for_period_select(value)
		options_for_select([
							[l(:label_this_week), 'current_week'],
							[l(:label_last_week), 'last_week'],
							[l(:label_this_month), 'current_month'],
							[l(:label_last_month), 'last_month']],
							value.blank? ? 'current_week' : value)
	end	

	def options_for_report_select(selectedRpt)
		options_for_select([
			[l(:label_wk_attendance), 'attendance_report'], 
			[l(:label_time_entry_plural), 'spent_time_report'], 
			[l(:label_wk_timesheet), 'time_report'], 
			[l(:label_wk_payslip), 'payslip_report'],
			[l(:label_wk_expensesheet), 'expense_report']], selectedRpt)
	end

end
