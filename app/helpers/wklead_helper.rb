module WkleadHelper
include WktimeHelper
include WkcrmHelper
include WkcrmactivityHelper
include WkinvoiceHelper
include WkcrmenumerationHelper

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
	
	def getFormComponent(fieldName, fieldValue, compSize, isShow)
		unless isShow
			text_field_tag(fieldName, fieldValue, :size => compSize)
		else
			fieldValue
		end
	end
end
