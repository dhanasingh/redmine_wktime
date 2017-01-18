module WkleadHelper
include WktimeHelper
include WkcrmHelper
include WkactivityHelper

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
	
	def getLeadStatusHash
		{
			'N' => l(:label_new),
			'A' =>l(:label_assigned), 
			'IP' => l(:label_in_process),
			'C' => l(:label_converted),
			'RC' => l(:label_recycled),
			'D' =>l(:label_dead)
		}
	end
	
	def getFormComponent(fieldName, fieldValue, compSize, isShow)
		unless isShow
			text_field_tag(fieldName, fieldValue, :size => compSize)
		else
			fieldValue
		end
	end
end
