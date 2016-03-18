module WkreportHelper	
	include WktimeHelper

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
