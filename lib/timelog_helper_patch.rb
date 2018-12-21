# require_dependency '../app/helpers/timelog_helper'
# require 'application_helper'
# module TimelogHelper
	
	# def format_criteria_value(criteria_options, value, html=true)
		# if value.blank?
			# "[#{l(:label_none)}]"
		# elsif k = criteria_options[:klass]
			# obj = k.find_by_id(value.to_i)
			# format_object(obj, html)
			# if obj.is_a?(Issue)
				# obj.visible? ? "#{obj.tracker} ##{obj.id}: #{obj.subject}" : "##{obj.id}"
	# # ============= ERPmine_patch Redmine 4.0  =====================					
			# elsif obj.is_a?(WkInventoryItem)
				# brandName = obj.product_item.brand.blank? ? "" : obj.product_item.brand.name
				# modelName = obj.product_item.product_model.blank? ? "" : obj.product_item.product_model.name
				# str = "#{obj.product_item.product.name} - #{brandName} - #{modelName}"
				# assetObj = obj.asset_property
				# str = str + ' - ' +assetObj.name unless assetObj.blank?
				# str
	# # ====================================			
			# else
				# obj
			# end
		# elsif cf = criteria_options[:custom_field]
			# format_value(value, cf)
		# else
			# value.to_s
		# end
	# end


# end