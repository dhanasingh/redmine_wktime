module WklogmaterialHelper
include ApplicationHelper
	def getLogHash
		{
			'T' => l(:label_wktime),
			'M' => l(:label_material)
		}
	end
end
