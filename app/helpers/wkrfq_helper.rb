module WkrfqHelper
include WktimeHelper

	def getRfqStatusHash
		status = { 'o'  => l(:label_open_issues), 'c' =>  l(:label_closed_issues) }
		status
	end
end
