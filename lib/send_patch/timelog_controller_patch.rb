module SendPatch::TimelogControllerPatch
	include Redmine::Pagination

	def self.included(base)
		base.class_eval do

			def index
			# ============= ERPmine_patch Redmine 6.1  =====================
					set_filter_session
				# =======================
				retrieve_time_entry_query
				scope = time_entry_scope.
				preload(:issue => [:project, :tracker, :status, :assigned_to, :priority]).
				preload(:project, :user)

			# ============= ERPmine_patch Redmine 6.1  =====================
					if session[:timelog][:spent_type] === "A" || session[:timelog][:spent_type] === "M"
						if session[:timelog][:spent_type] === "M"
							productType = 'I'
						else
							productType = session[:timelog][:spent_type]
						end
						scope = scope.where("wk_inventory_items.product_type = '#{productType}' ")
					end
					hookQuery = call_hook(:time_entry_detail_where_query, :params => params)
					unless hookQuery[0].blank?
						scope = scope.where(hookQuery[0])
					end
				# ==================
				respond_to do |format|
					format.html do
						@entry_count = scope.count
						@entry_pages = Paginator.new @entry_count, per_page_option, params['page']
						@entries = scope.offset(@entry_pages.offset).limit(@entry_pages.per_page).to_a

						render :layout => !request.xhr?
					end
					format.api do
						@entry_count = scope.count
						@offset, @limit = api_offset_and_limit
						@entries = scope.offset(@offset).limit(@limit).preload(:custom_values => :custom_field).to_a
					end
					format.atom do
						entries = scope.limit(Setting.feeds_limit.to_i).reorder("#{TimeEntry.table_name}.created_on DESC").to_a
						render_feed(entries, :title => l(:label_spent_time))
					end
					format.csv do
						# Export all entries
					entries = scope.to_a
					send_data(query_to_csv(entries, @query, params), :type => 'text/csv; header=present', :filename => "#{filename_for_export(@query, 'timelog')}.csv")
					end
				end
			end

			def report
				set_filter_session
				retrieve_time_entry_query
			# ============= ERPmine_patch Redmine 6.1  =====================
				options = session[:timelog][:spent_type] == "T" ? {nonSpentTime: params[:non_spent_time]} : {}
				scope = time_entry_scope(options)
					if session[:timelog][:spent_type] === "A" || session[:timelog][:spent_type] === "M"
						productType = session[:timelog][:spent_type] === "M" ? 'I' : 'A'
						scope = scope.where("wk_inventory_items.product_type = '#{productType}' ")
					end
					hookQuery = call_hook(:time_entry_report_where_query, :params => params)
					unless hookQuery[0].blank?
						scope = scope.where(hookQuery[0])
					end
				@report = Redmine::Helpers::TimeReport.new(@project, params[:criteria], params[:columns], scope, options)
				# ================================

				respond_to do |format|
					format.html {render :layout => !request.xhr?}
					format.csv do
					send_data(report_to_csv(@report), :type => 'text/csv; header=present',
					:filename => 'timelog.csv')
					end
				end
			end

			def edit
			# ============= ERPmine_patch Redmine 6.1  =====================
					@spentType = session[:timelog][:spent_type]
					if @spentType === "T"
				# =======================
					@time_entry.safe_attributes = params[:time_entry]
			# ============= ERPmine_patch Redmine 6.1  =====================
					elsif @spentType === "E"
						@expenseEntry = WkExpenseEntry.find(params[:id].to_i)
						@time_entry.project_id = @expenseEntry.project_id
						@time_entry.issue_id = @expenseEntry.issue_id
						@time_entry.activity_id = @expenseEntry.activity_id
						@time_entry.comments = @expenseEntry.comments
						@time_entry.spent_on = @expenseEntry.spent_on
						@time_entry.user_id = @expenseEntry.user_id
					else
						@materialEntry = WkMaterialEntry.find(params[:id].to_i)
						@time_entry.project_id = @materialEntry.project_id
						@time_entry.issue_id = @materialEntry.issue_id
						@time_entry.activity_id = @materialEntry.activity_id
						@time_entry.comments = @materialEntry.comments
						@time_entry.spent_on = @materialEntry.spent_on
						@time_entry.user_id = @materialEntry.user_id
					end
				# =======================
			end

			def retrieve_time_entry_query
			# ============= ERPmine_patch Redmine 6.1  =====================
					if !session[:timelog].blank? && (session[:timelog][:spent_type] == "M" || session[:timelog][:spent_type] == "A")
						retrieve_query(WkMaterialEntryQuery, false)
					elsif !session[:timelog].blank? && session[:timelog][:spent_type] == "E"
						retrieve_query(WkExpenseEntryQuery, false)
					else
				# =====================
					retrieve_query(TimeEntryQuery, false, :defaults => @default_columns_names)
			# ============= ERPmine_patch Redmine 6.1  =====================
					end
					hookModel = call_hook(:retrieve_time_entry_query_model, :params => params)
					unless hookModel[0].blank?
						retrieve_query(hookModel[0], false)
					end
				# =====================
			end

			def create
				@time_entry ||=
				TimeEntry.new(:project => @project, :issue => @issue,
										:author => User.current, :user => User.current,
										:spent_on => User.current.today)
				# ============= ERPmine_patch Redmine 6.1  =====================
				paramEntry = getParams(params[:log_type], params)
				@time_entry.safe_attributes = paramEntry
				#=====================
				if @time_entry.project && !User.current.allowed_to?(:log_time, @time_entry.project)
					render_403
					return
				end

				# ============= ERPmine_patch Redmine 6.1  =====================
					set_filter_session
					model = nil
					errorMsg = ""
					timeErrorMsg = ""
					errorMsg += l(:label_issue_error) if params[:clock_action] == "S" && paramEntry[:issue_id].blank?
					wktime_helper = Object.new.extend(WktimeHelper)
					if params[:log_type].blank? || params[:log_type] == 'T'
				#=====================
						call_hook(:controller_timelog_edit_before_save,
							{:params => params, :time_entry => @time_entry})

				# ============= ERPmine_patch Redmine 6.1  =====================
						errorMsg += wktime_helper.statusValidation(@time_entry)
						unless errorMsg.blank? && @time_entry.save
							timeErrorMsg = @time_entry.errors.full_messages.join("<br>")
						end
					else
						errorMsg += validateMatterial(paramEntry)
						if errorMsg.blank?
							errorMsg += saveMatterial if params[:log_type] == 'M' || params[:log_type] == 'A' || params[:log_type] == @logType
							errorMsg += saveExpense if params[:log_type] == 'E'
							model = @modelEntry
						end
					end
					if errorMsg.blank? && timeErrorMsg.blank?
						model = model.blank? ? @time_entry : model
						spentForModel = saveSpentFors(model)
					end
						#=====================
					respond_to do |format|
								format.html do
							# ============= ERPmine_patch Redmine 6.1  =====================
							if errorMsg.blank? && timeErrorMsg.blank?
							#=====================
								flash[:notice] = l(:notice_successful_create)
							# ============= ERPmine_patch Redmine 6.1 =====================
								if spentForModel.clock_action == "S"
									redirect_to controller: 'timelog', action: 'edit', id: model.id
								else
							#=====================
								if params[:continue]
									options = {
										:time_entry => {
											# ============= ERPmine_patch Redmine 6.1  =====================
											:project_id => paramEntry[:project_id],
											#=====================
											:issue_id => @time_entry.issue_id,
											:spent_on => @time_entry.spent_on,
											:activity_id => @time_entry.activity_id
										},
										:back_url => params[:back_url]
									}
									if params[:project_id] && @time_entry.project
										options[:time_entry][:project_id] ||= @time_entry.project.id
										redirect_to new_project_time_entry_path(@time_entry.project, options)
									elsif params[:issue_id] && @time_entry.issue
										redirect_to new_issue_time_entry_path(@time_entry.issue, options)
									else
										redirect_to new_time_entry_path(options)
									end
								else
									redirect_back_or_default project_time_entries_path(@time_entry.project)
								end
							end
							# ============= ERPmine_patch Redmine 6.1  =====================
							else
								flash[:error] = errorMsg if errorMsg.present?
								if @assetObj.present? && @assetObj.id.present? && @modelEntry.id.present?
									redirect_to :controller => 'timelog',:action => 'edit'
								else
									render :action => 'new'
								end
							end
							#=====================
						end
						format.api do
							# ============= ERPmine_patch Redmine 6.1 =====================
							if errorMsg.blank? && timeErrorMsg.blank?
								if params[:log_type].blank? || params[:log_type] == 'T' || params[:log_type] == 'A'
									renderLog
								else
									render :plain => errorMsg, :layout => nil
								end
							else
								errorMsg += timeErrorMsg if params[:log_type].blank? || params[:log_type] == 'T'
								@error_messages = errorMsg.split('\n')
								render :template => 'common/error_messages', :format => [:api], :status => :unprocessable_entity, :layout => nil
							end
							#=====================
						end
					end
			end

	# ============= ERPmine_patch Redmine 6.1  =====================
			def renderLog
				data = {}
				entry = params[:log_type] == 'A' ? @modelEntry : @time_entry
				if(params[:log_type] == 'A')
					inventoryItem = entry.inventory_item
					assetObj = entry.inventory_item.asset_property
					data = {log_type: 'A', id: entry.id, comments: entry.comments, spent_on: entry.spent_on, product_quantity: entry.quantity,product_sell_price: entry.selling_price, location_id: inventoryItem.location_id, rate_per: assetObj.rate_per,
					product_id: inventoryItem.product_item.product.id, uom_id: entry.uom_id, product_item_id: inventoryItem.product_item_id, available_quantity: inventoryItem.available_quantity, is_done: assetObj.nil? || assetObj.matterial_entry_id.nil?, inventory_item_id: entry.inventory_item_id}
					spentFor = WkMaterialEntry.find(entry.id).spent_for
				else
					data = {log_type: 'T', id: entry.id, hours: entry.hours, comments: entry.comments, spent_on: entry.spent_on}
					spentFor = TimeEntry.find(entry.id).spent_for
				end
				data['project'] = {id: entry.project_id}
				data['issue'] = {id: entry.issue_id}
				data['activity'] = {id: entry.activity_id}
				data['user'] = {id: entry.user_id}
				data['spentFor'] = {id: spentFor.id, start_on: spentFor.spent_on_time, end_on: spentFor.end_on, clock_action: spentFor.clock_action}
				render json: data.to_json
			end

			def saveSpentFors(model)
				spentForId = nil
				spentFortype = nil
				start_time = nil
				end_time = nil
				# ======Time Tracking=======
				wktime_helper = Object.new.extend(WktimeHelper)
				if wktime_helper.isChecked("label_enable_issue_logger") && ["T", "A"].include?(params[:log_type])
					dateTime = wktime_helper.get_current_DateTime(params[:offSet])
					start_time = params[:clock_action] == "S" && model.spent_for.blank? ? params[:start_on] && params[:start_on].to_time || dateTime : model.spent_for.spent_on_time if params[:clock_action].present?
					end_time = params[:clock_action] == "E" && model.spent_for.end_on.blank? ? params[:end_on] && params[:end_on].to_time || dateTime : model.spent_for.end_on if params[:clock_action].present? && model.spent_for.present?
				end
				unless params[:spent_for].blank?
					spentFors = params[:spent_for].split('|')
					spentForVal = spentFors[1].split('_')
					spentForId = spentForVal[1]
					spentFortype = spentForVal[0]
				end
				model = wktime_helper.saveSpentFor(params[:spentForId], spentForId, spentFortype, model.id, model.class.name, model.spent_on, '00', '00', nil, start_time, end_time, params[:latitude], params[:longitude], params[:clock_action])
			end

			def validateMatterial(paramEntry)
				errorMsg = ""
				# if paramEntry[:project_id].blank?
				# 	errorMsg = errorMsg + (errorMsg.blank? ? "" :  "<br/>") + l(:label_project_error) if params[:project_id].blank?
				# end
				if paramEntry[:issue_id].blank?
					errorMsg = errorMsg + (errorMsg.blank? ? "" :  "<br/>") + l(:label_issue_error)
				end
				if params[:expense_amount].blank? && params[:log_type] == 'E'
					errorMsg = errorMsg + (errorMsg.blank? ? "" :  "<br/>") + l(:error_expense_amount)
				end
				if paramEntry[:activity_id].blank?
					errorMsg = errorMsg + (errorMsg.blank? ? "" :  "<br/>") + l(:label_activity_error)
				end

				if params[:product_sell_price].blank? && (params[:log_type] == 'M' || params[:log_type] == 'A' || params[:log_type] == @logType)
					errorMsg = errorMsg + (errorMsg.blank? ? "" :  "<br/>") + l(:label_selling_price_error)
				end
				if params[:product_quantity].blank? && (params[:log_type] == 'M' || params[:log_type] == 'A' || params[:log_type] == @logType)
					errorMsg = errorMsg + (errorMsg.blank? ? "" :  "<br/>") + l(:label_quantity_error)
				end
				errorMsg
			end

			def getParams(logtype, params)
				hookType = call_hook(:update_time_entry_log_type, :params => params)
				@logType = 'A'
				unless hookType[0].blank?
					@logType = hookType[0]
				end
				param = params[:time_entry]
				param = params[:wk_expense_entry] if logtype == 'E'
				param = params[:wk_material_entry] if logtype == 'M' || logtype == 'A' || params[:log_type] == @logType
				param
			end
		# ========================

			def update
				# ============= ERPmine_patch Redmine 6.1  =====================
				paramEntry = getParams(params[:log_type], params)
				@time_entry.safe_attributes = paramEntry
				model = nil
				errorMsg = ""
				timeErrorMsg = ""
				@spentType = params[:log_type].blank? ? "T" : params[:log_type]
				wktime_helper = Object.new.extend(WktimeHelper)
				if params[:log_type].blank? || params[:log_type] == 'T'
				# =========================
					call_hook(:controller_timelog_edit_before_save,
						{:params => params, :time_entry => @time_entry})
				# ============= ERPmine_patch Redmine 6.1  =====================
					if params[:clock_action] == "E" && @time_entry.spent_for.end_on.blank?
						end_on = Time.now - (Time.now.utc_offset.seconds + (params[:offSet].to_i).minutes)
						@time_entry.hours = ((end_on - @time_entry.spent_for.spent_on_time)/3600).round(2)
					end
					errorMsg += wktime_helper.statusValidation(@time_entry)
					errorMsg += l(:error_issue_logger) if params[:clock_action] == "S" && @time_entry.spent_for.end_on.blank?
					unless errorMsg.blank? && @time_entry.save
						timeErrorMsg = @time_entry.errors.full_messages.join("<br>")
					end
				else
					errorMsg = validateMatterial(paramEntry)
					if errorMsg.blank?
						errorMsg += saveMatterial if params[:log_type] == 'M' || params[:log_type] == 'A' || params[:log_type] == @logType
						errorMsg += saveExpense if params[:log_type] == 'E'
						model = @modelEntry
					end
				end
				model = model.blank? ? @time_entry : model
				if errorMsg.blank? && timeErrorMsg.blank?
					spentForModel = saveSpentFors(model)
				end
				# =========================
				respond_to do |format|
					format.html do
						# ============= ERPmine_patch Redmine 6.1  =====================
						if errorMsg.blank? && timeErrorMsg.blank?
						# =========================
							flash[:notice] = l(:notice_successful_update)
							# ============= ERPmine_patch Redmine 6.1  =====================
							if spentForModel.clock_action == "E" && params[:commit] != "Save"
								redirect_to controller: 'timelog', action: 'edit', id: model.id
							else
							# =========================
								redirect_back_or_default project_time_entries_path(@time_entry.project)
							end
						# ============= ERPmine_patch Redmine 6.1  =====================
						else
							flash[:error] = (errorMsg + timeErrorMsg)
							redirect_to controller: 'timelog', action: 'edit', id: model.id
						end
					end
					format.api do
						if errorMsg.blank? && timeErrorMsg.blank?
							if params[:log_type].blank? || params[:log_type] == 'T' || params[:log_type] == 'A'
								renderLog
							else
								render :plain => errorMsg, :layout => nil
							end
						else
							errorMsg += timeErrorMsg if params[:log_type].blank? || params[:log_type] == 'T'
							@error_messages = errorMsg.split('\n')
							render :template => 'common/error_messages', :format => [:api], :status => :unprocessable_entity, :layout => nil
							# =========================
						end
					end
				end
			end

	# ============= ERPmine_patch Redmine 6.1  =====================
			def saveMatterial
				wklog_helper = Object.new.extend(WklogmaterialHelper)
				wktime_helper = Object.new.extend(WktimeHelper)
				setEntries(WkMaterialEntry, params[:matterial_entry_id], params[:wk_material_entry])
				selPrice = params[:product_sell_price].to_f
				@modelEntry.selling_price = selPrice.blank? ? 0.00 :  ("%.2f" % selPrice)
				@modelEntry.uom_id = params[:uom_id]
				inventoryId = ""
				errorMsg = ""
				if params[:clock_action] == "S" && @modelEntry.spent_for && @modelEntry.spent_for.end_on.blank?
					errorMsg = l(:error_issue_logger)
				else
					inventoryItemObj = WkInventoryItem.find(params[:inventory_item_id].to_i) if !params[:inventory_item_id].blank?
					if params[:log_type] == 'M' && !params[:inventory_item_id].blank?
						inventoryObj = wklog_helper.updateParentInventoryItem(params[:inventory_item_id].to_i, params[:product_quantity].to_i, @modelEntry.quantity)
						inventoryId =  inventoryObj.id
						currency =  inventoryObj.currency
					else
						inventoryId =  params[:inventory_item_id]
						currency = Setting.plugin_redmine_wktime['wktime_currency']
					end
					if inventoryId.blank?
						errorMsg += l(:error_item_not_available)
					elsif params[:product_quantity].to_i > inventoryItemObj.available_quantity.to_i
						errorMsg += l(:error_product_qty_greater_avail_qty)
					else
						if params[:log_type] == "A" && params[:clock_action] == "S" && @modelEntry.spent_for.blank?
							quantity = "0.1"
						elsif params[:log_type] == "A" && params[:clock_action] == "E" && @modelEntry.spent_for.present? && @modelEntry.spent_for.end_on.blank?
							quantity = wktime_helper.getAssetQuantity(@modelEntry.spent_for.spent_on_time, wktime_helper.get_current_DateTime(params[:offSet]), params[:inventory_item_id])
						else
							quantity = params[:product_quantity]
						end
						@modelEntry.inventory_item_id = inventoryId.to_i
						@modelEntry.quantity = quantity
						@modelEntry.currency = currency
						unless @modelEntry.valid?
							errorMsg = @modelEntry.errors.full_messages.join("<br>")
						else
							@modelEntry.save
						end
						if params[:log_type] == 'A' || params[:log_type] == @logType
							inventoryObj = WkInventoryItem.find(inventoryId.to_i)
							@assetObj = inventoryObj.asset_property
							if params[:matterial_entry_id].blank? ||(params[:is_done].blank? || params[:is_done] == "0")
								@assetObj.matterial_entry_id = @modelEntry.id
							else
								@assetObj.matterial_entry_id = nil
							end
							@assetObj.save
						end
						# save serial number
						wklog_helper.saveConsumedSN(JSON.parse(params[:hidden_sns]), @modelEntry) if errorMsg.blank? && params[:hidden_sns].present?
					end
				end
				return errorMsg
			end

			def setEntries(model, id, params={})
				if id.blank?
					@modelEntry = model.new
				else
					@modelEntry = model.find(id.to_i)
				end
				projectId = Issue.find(params[:issue_id].to_i).project_id
				@modelEntry.project_id = projectId
				@modelEntry.user_id = params[:user_id].blank? ? User.current.id : params[:user_id].to_i
				@modelEntry.issue_id =  params[:issue_id].to_i
				@modelEntry.comments =  params[:comments]
				@modelEntry.activity_id =  params[:activity_id].to_i
				@modelEntry.spent_on = params[:spent_on]
			end

			def saveExpense
				errorMsg = ""
				setEntries(WkExpenseEntry, params[:expense_entry_id], params[:wk_expense_entry])
				@modelEntry.amount = params[:expense_amount]
				@modelEntry.currency = params[:wktime_currency]
				unless @modelEntry.valid?
					errorMsg = @modelEntry.errors.full_messages.join("<br>")
				else
					@modelEntry.save
				end
				return errorMsg
			end

			def set_filter_session
				if params[:spent_type].blank? && params[:log_type].blank?
					session[:timelog] = {:spent_type => "T"} if session[:timelog].blank? || session[:timelog][:spent_type].blank?
				else
					session[:timelog] = {} if session[:timelog].blank?
					session[:timelog][:spent_type] = params[:log_type].blank? ? params[:spent_type] : params[:log_type]
					session[:timelog][:show_on_map] = params[:show_on_map]
				end
			end
		# =======================================

			def find_time_entries
				# ============= ERPmine_patch Redmine 6.1  =====================
				set_filter_session
				if session[:timelog][:spent_type] === "T"
				# ==========================================
					@time_entries = TimeEntry.where(:id => params[:id] || params[:ids]).
						preload(:project => :time_entry_activities).
						preload(:user).to_a
					raise Unauthorized unless @time_entries.all? {|t| t.editable_by?(User.current)}
				# ============= ERPmine_patch Redmine 6.1  =====================
				elsif session[:timelog][:spent_type] === "E"
					@time_entries = WkExpenseEntry.where(:id => params[:id] || params[:ids])
				else
					@time_entries = WkMaterialEntry.where(:id => params[:id] || params[:ids])
					raise ActiveRecord::RecordNotFound if @time_entries.empty?
				# ===================================
				end
				@projects = @time_entries.filter_map(&:project).uniq
				@project = @projects.first if @projects.size == 1
				rescue ActiveRecord::RecordNotFound
				render_404
			end

			def find_time_entry
    		# ============= ERPmine_patch Redmine 6.1  =====================
				set_filter_session
				if session[:timelog][:spent_type] === "T"
					# ========================
					@time_entry = TimeEntry.find(params[:id])
				# ============= ERPmine_patch Redmine 6.1  =====================
						elsif session[:timelog][:spent_type] === "E"
							@time_entry = WkExpenseEntry.find(params[:id])
						else
							@time_entry = WkMaterialEntry.find(params[:id])
						end
							# ==============================================
				@project = @time_entry.project
					rescue ActiveRecord::RecordNotFound
				render_404
				end

			def check_editability
      		# ============= ERPmine_patch Redmine 6.1  =====================
						wktime_helper = Object.new.extend(WktimeHelper)
						set_filter_session
						if session[:timelog][:spent_type] === "T"
							# =============================
							unless @time_entry.editable_by?(User.current)
									render_403
									return false
							end
      		# ============= ERPmine_patch Redmine 6.1  =====================
						elsif session[:timelog][:spent_type] === "E"
							return true
						else
							return wktime_helper.showInventory
						end
						# =============================
			end

			def bulk_edit
			# ============= ERPmine_patch Redmine 6.1  =====================
				if session[:timelog][:spent_type] == "T"
				# =============================
					@target_projects = Project.allowed_to(:log_time).to_a
					@custom_fields = TimeEntry.first.available_custom_fields.select {|field| field.format.bulk_edit_supported}
					if params[:time_entry]
						@target_project = @target_projects.detect {|p| p.id.to_s == params[:time_entry][:project_id].to_s}
					end
					if @target_project
						@available_activities = @target_project.activities
					else
						@available_activities = @projects.map(&:activities).reduce(:&)
					end
			# ============= ERPmine_patch Redmine 6.1  =====================
				else
					render_404
				end
				# =============================
				@time_entry_params = params[:time_entry] || {}
				@time_entry_params[:custom_field_values] ||= {}
			end

			def bulk_update
				attributes = parse_params_for_bulk_update(params[:time_entry])

				unsaved_time_entries = []
				saved_time_entries = []

				@time_entries.each do |time_entry|
					time_entry.reload
					time_entry.safe_attributes = attributes
					call_hook(
					:controller_time_entries_bulk_edit_before_save,
					{:params => params, :time_entry => time_entry}
					)
				# ============= ERPmine_patch Redmine 6.1  =====================
					wktime_helper = Object.new.extend(WktimeHelper)
					errorMsg = wktime_helper.statusValidation(time_entry)
					if errorMsg.blank? && time_entry.save
					# =============================
						saved_time_entries << time_entry
					else
						unsaved_time_entries << time_entry
					end
				end

				if unsaved_time_entries.empty?
					flash[:notice] = l(:notice_successful_update) unless saved_time_entries.empty?
					redirect_back_or_default project_time_entries_path(@projects.first)
				else
					@saved_time_entries = @time_entries
					@unsaved_time_entries = unsaved_time_entries
					@time_entries = TimeEntry.where(:id => unsaved_time_entries.map(&:id)).
						preload(:project => :time_entry_activities).
						preload(:user).to_a

					bulk_edit
					render :action => 'bulk_edit'
				end
			end

			def destroy
      		# ============= ERPmine_patch Redmine 6.1  =====================
						wktime_helper = Object.new.extend(WktimeHelper)
							errMsg = ""
							if session[:timelog][:spent_type] === "T"
								# ============================
								destroyed = TimeEntry.transaction do
						@time_entries.each do |t|
					# ============= ERPmine_patch Redmine 6.1  =====================
						status = wktime_helper.getTimeEntryStatus(t.spent_on, t.user_id)
						if !status.blank? && ('a' == status || 's' == status || 'l' == status)
							errMsg = "#{l(:error_time_entry_delete)}"
							raise ActiveRecord::Rollback
						end
						if errMsg.blank?
							# ===========================
							unless t.destroy && t.destroyed?
							# ============= ERPmine_patch Redmine 6.1  =====================
								errMsg = l(:notice_unable_delete_time_entry)
								# ============================
								raise ActiveRecord::Rollback
							end
						end
								end
      				# ============= ERPmine_patch Redmine 6.1  =====================
								end
					elsif session[:timelog][:spent_type] === "E"
						destroyed = WkExpenseEntry.transaction do
							@time_entries.each do |e|
								status = wktime_helper.getExpenseEntryStatus(e.spent_on, e.user_id)
								errMsg = "#{l(:error_expense_delete)}" if !status.blank? && ('a' == status || 's' == status || 'l' == status)
								raise ActiveRecord::Rollback unless errMsg.blank? && e.destroy && e.destroyed?
							end
						end
					else
						if wktime_helper.validateERPPermission("D_INV")
							destroyed = WkMaterialEntry.transaction do
								begin
								if @time_entries.spent_for.blank? || @time_entries.spent_for.invoice_item_id.blank?
									if session[:timelog][:spent_type] === "M"
										inventoryItemObj = WkInventoryItem.find(@time_entries.inventory_item_id)
										inventoryItemObj.available_quantity = inventoryItemObj.available_quantity + @time_entries.quantity
										inventoryItemObj.save
									end
									@time_entries.destroy
								else
									errMsg = l(:error_material_delete_billed)
									logger.error ex.message
									raise ActiveRecord::Rollback
								end
								rescue => ex
									errMsg = l(:error_material_delete)
									logger.error ex.message
									raise ActiveRecord::Rollback
								end
							end
							destroyed = WkMaterialEntry.transaction do
								@time_entries.each do |m|
									if m.spent_for.blank? || m.spent_for.invoice_item_id.blank?
										if session[:timelog][:spent_type] === "M"
											inventoryItemObj = WkInventoryItem.find(m.inventory_item_id)
											inventoryItemObj.available_quantity = inventoryItemObj.available_quantity + m.quantity
											inventoryItemObj.save
										end
										raise ActiveRecord::Rollback unless m.destroy && m.destroyed?
									else
										errMsg = l(:error_material_delete_billed)
										raise ActiveRecord::Rollback
									end
								end
							end
						else
							render_403
							return false
						end
					end
				# ==========================================
				respond_to do |format|
					format.html do
							if destroyed
								flash[:notice] = l(:notice_successful_delete)
							else
              # ============= ERPmine_patch Redmine 6.1  =====================
								flash[:error] = errMsg || l(:notice_unable_delete_time_entry)
								# ==========================================
							end
						redirect_back_or_default project_time_entries_path(@projects.first), :referer => true
					end
					format.api do
						if destroyed
							render_api_ok
						else
							render_validation_errors(@time_entries)
						end
					end
				end
			end

		end
	end
end
