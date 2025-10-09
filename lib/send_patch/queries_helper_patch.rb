module SendPatch::QueriesHelperPatch
	def self.included(base)
		base.class_eval do

			# module InstanceMethods
			def column_value_with_wktime_projects(column, item, value)
				case column.name
			# ============= ERPmine_patch Redmine 6.1 =====================
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
					column_value_without_wktime_projects(column, item, value)
				end
			end
			alias_method :column_value_without_wktime_projects, :column_value
			alias_method :column_value, :column_value_with_wktime_projects

			def render_query_totals(query)
				return unless query.totalable_columns.present?

				totals = query.totalable_columns.map do |column|
			# ============= ERPmine_patch Redmine 6.1  =====================
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

				Redmine::Export::CSV.generate(encoding: params[:encoding], field_separator: params[:field_separator]) do |csv|
					# csv header fields
					csv << columns.map {|c| c.caption.to_s}
					# csv lines
					items.each do |item|
			# ============= ERPmine_patch Redmine 6.1  =====================
					csv << columns.map {|c| [:inventory_item_id].include?(c.name) ? wk_csv_content(item) : csv_content(c, item)}
					# =============================
					end
				end
			end

  		# ============= ERPmine_patch Redmine 6.1  =====================
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

			# Renders the list of queries for the sidebar
			def render_sidebar_queries(klass, project)
			#	============= ERPmine_patch Redmine 6.1  =====================
				spent_type = session[:timelog] && session[:timelog][:spent_type]
				kclassName =  spent_type == "M" || spent_type == "A" ? WkMaterialEntryQuery : (spent_type == 'E' ? WkExpenseEntryQuery : klass)
				queries = sidebar_queries(kclassName, project)
				# =============================

				out = ''.html_safe
				out << query_links(l(:label_my_queries), queries.select(&:is_private?))
				out << query_links(l(:label_query_plural), queries.reject(&:is_private?))
				out
			end

		end
	end
end