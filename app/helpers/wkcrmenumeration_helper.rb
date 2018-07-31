module WkcrmenumerationHelper
include WktimeHelper

	def enumType
		enumerationType = {
			'' => '',
			'LS' => l(:label_lead_source),
			'SS' => l(:label_txn_sales_stage),
			'OT' => l(:label_opportunity_type),
			'AC' => l(:label_account_category),
			'PT' => l(:label_payment_type),
			'LT' => l(:label_location_type),
			'DP' => l(:label_department),
			'CR' => l(:label_relationship)
		}
		enumhash = call_hook :external_enum_type
		unless enumhash.blank?
			mergeHash = eval(enumhash)
			enumerationType =  enumerationType.merge(mergeHash)
		end
		enumerationType	
	end
	
	def options_for_enum_select(enumType, value, needBlank)
		ennumArray = Array.new
		defaultValue = 0
		crmenum = WkCrmEnumeration.where(:enum_type => enumType, :active => true).order(enum_type: :asc, position: :asc, name: :asc)
		if !crmenum.blank?
			crmenum.each do | entry|				
				ennumArray <<  [I18n.t("#{entry.name.gsub('.', '/')}", :default => entry.name), entry.id  ]
				defaultValue = entry.id if entry.is_default?# === "true"
			end
		end
		if needBlank
			ennumArray.unshift(["",0]) 
		end
		options_for_select(ennumArray, value.blank? ? defaultValue : value)
	end
	
end
