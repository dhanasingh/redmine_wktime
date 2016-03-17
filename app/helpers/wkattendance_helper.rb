module WkattendanceHelper	
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
	
	#Copied from UserHelper
	def users_status_options_for_select(selected)
		user_count_by_status = User.group('status').count.to_hash
		options_for_select([[l(:label_all), ''],
                        ["#{l(:status_active)} (#{user_count_by_status[1].to_i})", '1'],
                        ["#{l(:status_registered)} (#{user_count_by_status[2].to_i})", '2'],
                        ["#{l(:status_locked)} (#{user_count_by_status[3].to_i})", '3']], selected.to_s)
	end

end
