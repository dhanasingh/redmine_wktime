require_dependency '../app/helpers/queries_helper'
require 'application_helper'

module QueriesHelper
	def column_value(column, item, value)
		case column.name
		when :id
		  link_to value, issue_path(item)
		when :subject
		  link_to value, issue_path(item)
		when :parent
		  value ? (value.visible? ? link_to_issue(value, :subject => false) : "##{value.id}") : ''
		when :description
		  item.description? ? content_tag('div', textilizable(item, :description), :class => "wiki") : ''
		when :last_notes
		  item.last_notes.present? ? content_tag('div', textilizable(item, :last_notes), :class => "wiki") : ''
		when :done_ratio
		  progress_bar(value)
		when :relations
		  content_tag('span',
			value.to_s(item) {|other| link_to_issue(other, :subject => false, :tracker => false)}.html_safe,
			:class => value.css_classes_for(item))
		when :hours, :estimated_hours
		  format_hours(value)
		when :spent_hours
		  link_to_if(value > 0, format_hours(value), project_time_entries_path(item.project, :issue_id => "#{item.id}"))
		when :total_spent_hours
		  link_to_if(value > 0, format_hours(value), project_time_entries_path(item.project, :issue_id => "~#{item.id}"))
		when :attachments
		  value.to_a.map {|a| format_object(a)}.join(" ").html_safe
	# ============= ERPmine_patch Redmine 4.0  =====================	  
		when :inventory_item_id
			val = item.inventory_item.product_item.product.name
			assetObj = item.inventory_item.asset_property
			value = assetObj.blank? ? val : val + ' - ' + assetObj.name
		when :selling_price
			val = item.selling_price * item.quantity
			value = val.blank? ? 0.00 : ("%.2f" % val)
		when :resident_id
			val = item.resident.name
			value = val
		when :resident_type
			value = item.resident.location.name
		when :apartment_id
			value = item.apartment.blank? ? "" : item.apartment.asset_property.name
		when :bed_id
			value = item.bed.blank? ? "" : item.bed.asset_property.name
   # =============================		
		else
		  format_object(value)
		end
	  end

end