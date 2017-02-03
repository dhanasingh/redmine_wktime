module WkcrmenumerationHelper
include WktimeHelper

	def enumType
		enumerationType = {
			'' => '',
			'LS' => l(:label_lead_source),
			'SS' => l(:label_txn_sales) + " " + l(:label_stage),
			'OT' => l(:label_opportunity) + " " + l(:label_type),
			'AC' => l(:label_account) + " " + l(:field_category)
		}
		enumerationType	
	end
	
	def options_for_enum_select(enumType, value)
		ennumArray = Array.new
		defaultValue = 0
		crmenum = WkCrmEnumeration.where(:enum_type => enumType).order(enum_type: :asc, position: :asc, name: :asc)
		if !crmenum.blank?
			crmenum.each do | entry|				
				ennumArray <<  [entry.name, entry.id  ]
				defaultValue = entry.id if entry.is_default?# === "true"
			end
		end
		ennumArray.unshift(["",0]) 
		options_for_select(ennumArray, value.blank? ? defaultValue : value)
	end
	
end
