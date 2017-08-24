require_dependency '../app/helpers/timelog_helper'
require 'application_helper'
module TimelogHelper
	
	def format_criteria_value(criteria_options, value)
		if value.blank?
			"[#{l(:label_none)}]"
		elsif k = criteria_options[:klass]
			obj = k.find_by_id(value.to_i)
			if obj.is_a?(Issue)
				obj.visible? ? "#{obj.tracker} ##{obj.id}: #{obj.subject}" : "##{obj.id}"
			elsif obj.is_a?(WkInventoryItem)
				"#{obj.product_item.product.name} - #{obj.product_item.brand.name} - #{obj.product_item.product_model.name}"
			else
				obj
			end
		elsif cf = criteria_options[:custom_field]
			format_value(value, cf)
		else
			value.to_s
		end
	end


end