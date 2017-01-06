module WkleadHelper
include WktimeHelper

	def getLeadStatusArr
		[
			[l(:label_new),'N'],
			[l(:label_assigned),'A'], 
			[l(:label_in_process),'IP'],
			[l(:label_converted),'C'],
			[l(:label_recycled),'RC'],
			[l(:label_dead),'D']
		]
	end
end
