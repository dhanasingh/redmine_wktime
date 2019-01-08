require_dependency '../app/helpers/application_helper'

module WkApplicationHelperPatch
   
  def format_object(object, html=true, &block)
    if block_given?
      object = yield object
    end
    case object.class.name
    when 'Array'
      formatted_objects = object.map {|o| format_object(o, html)}
      html ? safe_join(formatted_objects, ', ') : formatted_objects.join(', ')
    when 'Time'
      format_time(object)
    when 'Date'
      format_date(object)
    when 'Fixnum'
      object.to_s
    when 'Float'
      sprintf "%.2f", object
    when 'User'
      html ? link_to_user(object) : object.to_s
    when 'Project'
      html ? link_to_project(object) : object.to_s
    when 'Version'
      html ? link_to_version(object) : object.to_s
    when 'TrueClass'
      l(:general_text_Yes)
    when 'FalseClass'
      l(:general_text_No)
    when 'Issue'
      object.visible? && html ? link_to_issue(object) : "##{object.id}"
    when 'Attachment'
      html ? link_to_attachment(object) : object.filename
	# ============= ERPmine_patch Redmine 4.0  =====================  
	when 'WkInventoryItem'
	  brandName = obj.product_item.brand.blank? ? "" : obj.product_item.brand.name
	  modelName = obj.product_item.product_model.blank? ? "" : obj.product_item.product_model.name
	  str = "#{obj.product_item.product.name} - #{brandName} - #{modelName}"
	  assetObj = obj.asset_property
	  str = str + ' - ' +assetObj.name unless assetObj.blank?
	  str
	# =============================  
    when 'CustomValue', 'CustomFieldValue'
      if object.custom_field
        f = object.custom_field.format.formatted_custom_value(self, object, html)
        if f.nil? || f.is_a?(String)
          f
        else
          format_object(f, html, &block)
        end
      else
        object.value.to_s
      end
    else
      html ? h(object) : object.to_s
    end
  end
end  