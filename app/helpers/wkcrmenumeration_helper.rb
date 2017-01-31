module WkcrmenumerationHelper
include WktimeHelper

	def enumType
		enumerationType = {
			'' => '',
			'LeadSource' => l(:label_lead_source),
			'SalesStage' => l(:label_txn_sales) + " " + l(:label_stage)
		}
		enumerationType	
	end
end
