module QueriesHelper
	def column_value(column, item, value)
    content =
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
      content_tag(
        'span',
			value.to_s(item) {|other| link_to_issue(other, :subject => false, :tracker => false)}.html_safe,
			:class => value.css_classes_for(item))
		when :hours, :estimated_hours, :total_estimated_hours
		  format_hours(value)
		when :spent_hours
		  link_to_if(value > 0, format_hours(value), project_time_entries_path(item.project, :issue_id => "#{item.id}"))
		when :total_spent_hours
		  link_to_if(value > 0, format_hours(value), project_time_entries_path(item.project, :issue_id => "~#{item.id}"))
		when :attachments
		  value.to_a.map {|a| format_object(a)}.join(" ").html_safe
	# ============= ERPmine_patch Redmine 5.0  =====================
		when :inventory_item_id
			formProductItem(item)
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
    call_hook(:helper_queries_column_value,
              {:content => content, :column => column, :item => item, :value => value})

    content
	end

	def render_query_totals(query)
		return unless query.totalable_columns.present?

		totals = query.totalable_columns.map do |column|
			# ============= ERPmine_patch Redmine 5.0  =====================
			if [:quantity, :selling_price].include? column.name
				product_type = session[:timelog][:spent_type] == "M" ? 'I' : session[:timelog][:spent_type]
				query[:filters]['product_type'] = {"operator":"=","values" => product_type}
			end
			# =============================
		total_tag(column, query.total_for(column))
		end
		content_tag('p', totals.join(" ").html_safe, :class => "query-totals")
	end

	def query_to_csv(items, query, options={})
    columns = query.columns

    Redmine::Export::CSV.generate(:encoding => params[:encoding]) do |csv|
      # csv header fields
      csv << columns.map {|c| c.caption.to_s}
      # csv lines
      items.each do |item|
        # ============= ERPmine_patch Redmine 5.0  =====================
        csv << columns.map {|c| [:inventory_item_id].include?(c.name) ? wk_csv_content(item) : csv_content(c, item)}
        # =============================
      end
    end
  end

  # ============= ERPmine_patch Redmine 5.0  =====================
	def wk_csv_content(item)
		formProductItem(item)
	end

	def formProductItem(item)
		brandName = item.inventory_item&.product_item&.brand.blank? ? "" : item.inventory_item&.product_item&.brand&.name
		modelName = item.inventory_item&.product_item&.product_model.blank? ? "" : item.inventory_item&.product_item&.product_model&.name
		serialNo = item.inventory_item&.serial_number.blank? ? "" : item.inventory_item&.serial_number&.to_s
		runSerialNo = item.inventory_item&.running_sn.blank? ? "" : item.inventory_item&.running_sn&.to_s
		val = item.inventory_item.product_item.product.name
		product_items = "#{brandName} - #{modelName} - #{serialNo + runSerialNo}"
		assetObj = item.inventory_item.asset_property
		value = item&.inventory_item&.product_type == 'I' ? val+' - '+product_items : val +' - '+ assetObj.name
	end
	# =============================
end