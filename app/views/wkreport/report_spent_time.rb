module ReportSpentTime
	require_relative "../wkreport/report_attendance"
	include ReportAttendance

	def getType
		return 'spent_time'
	end
end