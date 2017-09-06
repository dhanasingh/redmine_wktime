require_dependency '../lib/redmine/Pagination'		
module TimelogControllerPatch
	def self.included(base)
	base.class_eval do
		def index
			set_filter_session
			retrieve_time_entry_query
			scope = time_entry_scope.
			preload(:issue => [:project, :tracker, :status, :assigned_to, :priority]).
			preload(:project, :user)
			
			respond_to do |format|
				format.html {
					@entry_count = scope.count
					@entry_pages = Paginator.new @entry_count, per_page_option, params['page']
					@entries = scope.offset(@entry_pages.offset).limit(@entry_pages.per_page).to_a
					render :layout => !request.xhr?
				}
				format.api  {
					@entry_count = scope.count
					@offset, @limit = api_offset_and_limit
					@entries = scope.offset(@offset).limit(@limit).preload(:custom_values => :custom_field).to_a
				}
				format.atom {
					entries = scope.limit(Setting.feeds_limit.to_i).reorder("#{TimeEntry.table_name}.created_on DESC").to_a
					render_feed(entries, :title => l(:label_spent_time))
				}
				format.csv {
					# Export all entries
					@entries = scope.to_a
					send_data(query_to_csv(@entries, @query, params), :type => 'text/csv; header=present', :filename => 'timelog.csv')
				}
			end
		end

		def edit
			if session[:timelog][:spent_type] === "T"
				@time_entry.safe_attributes = params[:time_entry]
			else
				@spentType = session[:timelog][:spent_type]
				@materialEntry = WkMaterialEntry.find(params[:id].to_i)					
				@time_entry.project_id = @materialEntry.project_id
				@time_entry.issue_id = @materialEntry.issue_id
				@time_entry.activity_id = @materialEntry.activity_id
				@time_entry.comments = @materialEntry.comments
				@time_entry.spent_on = @materialEntry.spent_on
			end
		end

		def retrieve_time_entry_query
			if !params[:spent_type].blank? && params[:spent_type] == "M"
				retrieve_query(WkMaterialEntryQuery, false)
			else
				retrieve_query(TimeEntryQuery, false)
			end
		end

		def create				
			@time_entry ||= TimeEntry.new(:project => @project, :issue => @issue, :user => User.current, :spent_on => User.current.today)
			@time_entry.safe_attributes = params[:time_entry]
			if @time_entry.project && !User.current.allowed_to?(:log_time, @time_entry.project)
				render_403
				return
			end

			call_hook(:controller_timelog_edit_before_save, { :params => params, :time_entry => @time_entry })
			
			if params[:log_type].blank? || params[:log_type] == 'T'
				if @time_entry.save
					respond_to do |format|
						format.html {
							flash[:notice] = l(:notice_successful_create)
							if params[:continue]
								options = {
									:time_entry => {
										:project_id => params[:time_entry][:project_id],
										:issue_id => @time_entry.issue_id,
										:activity_id => @time_entry.activity_id
									},
									:back_url => params[:back_url]
								}
								if params[:project_id] && @time_entry.project
									redirect_to new_project_time_entry_path(@time_entry.project, options)
								elsif params[:issue_id] && @time_entry.issue
									redirect_to new_issue_time_entry_path(@time_entry.issue, options)
								else
									redirect_to new_time_entry_path(options)
								end
							else
								redirect_back_or_default project_time_entries_path(@time_entry.project)
							end
							}
							format.api  { render :action => 'show', :status => :created, :location => time_entry_url(@time_entry) }
						end
					else
					respond_to do |format|
						format.html { render :action => 'new' }
						format.api  { render_validation_errors(@time_entry) }
					end
				end
			else				
				errorMsg = validateMatterial				
				if errorMsg.blank?
					saveMatterial
				else
					respond_to do |format|
						format.html { 					
							flash[:error] = errorMsg
							render :action => 'new'
						
						}
					end
				end
			end
		end
		
		def validateMatterial
			errorMsg = ""
			
			if params[:time_entry][:project_id].blank? 
				errorMsg = errorMsg + (errorMsg.blank? ? "" :  "<br/>") + l(:label_project_error) if params[:project_id].blank?
			end
			if params[:time_entry][:issue_id].blank?
				errorMsg = errorMsg + (errorMsg.blank? ? "" :  "<br/>") + l(:label_issue_error)
			end
			if params[:time_entry][:activity_id].blank?
				errorMsg = errorMsg + (errorMsg.blank? ? "" :  "<br/>") + l(:label_activity_error)
			end
			if params[:product_sell_price].blank?
				errorMsg = errorMsg + (errorMsg.blank? ? "" :  "<br/>") + l(:label_selling_price_error) 
			end
			if params[:product_quantity].blank?
				errorMsg = errorMsg + (errorMsg.blank? ? "" :  "<br/>") + l(:label_quantity_error)
			end
			errorMsg
		end

		def update
			@time_entry.safe_attributes = params[:time_entry]

			call_hook(:controller_timelog_edit_before_save, { :params => params, :time_entry => @time_entry })

			if params[:log_type].blank? || params[:log_type] == 'T'
				if @time_entry.save
					respond_to do |format|
						format.html {
						flash[:notice] = l(:notice_successful_update)
						redirect_back_or_default project_time_entries_path(@time_entry.project)
						}
						format.api  { render_api_ok }
					end
				else
					respond_to do |format|
						format.html { render :action => 'edit' }
						format.api  { render_validation_errors(@time_entry) }
					end
				end
			else
				errorMsg = validateMatterial				
				if errorMsg.blank?
					saveMatterial
				else
					respond_to do |format|
						format.html { 					
							flash[:error] = errorMsg
							redirect_back_or_default project_time_entries_path(@time_entry.project)
						
						}
					end
				end
			end
		end
		
		def saveMatterial
			wklog_helper = Object.new.extend(WklogmaterialHelper)	
			setMatterialEntries	
			begin				
				inventoryObj = wklog_helper.updateParentInventoryItem(params[:inventory_item_id].to_i, params[:product_quantity].to_i, @materialEntries.quantity)
				inventoryId = inventoryObj.id
				if inventoryId.blank?
					errorMsg = "Requested no of items not available in the stock"
				else
					@materialEntries.inventory_item_id = inventoryId
					@materialEntries.quantity = params[:product_quantity].to_i
					@materialEntries.currency = inventoryObj.currency
					unless @materialEntries.valid?	
						errorMsg = @materialEntries.errors.full_messages.join("<br>")
					else 
						@materialEntries.save
					end
				end
				respond_to do |format|
					format.html { 
					unless errorMsg.blank?
						flash[:error] = errorMsg
						render :action => 'new'
					else
						flash[:notice] = l(:notice_successful_update)
						redirect_back_or_default project_time_entries_path(@time_entry.project)
					end
					 
					}
				end
			rescue => ex
				logger.error ex.message
			end
		end

		def setMatterialEntries
			if params[:matterial_entry_id].blank?
				@materialEntries = WkMaterialEntry.new
			else
				@materialEntries = WkMaterialEntry.find(params[:matterial_entry_id].to_i)
			end
			@materialEntries.project_id =  @project.blank? ? params[:time_entry][:project_id] : @project.id 
			@materialEntries.user_id = User.current.id
			@materialEntries.issue_id =  params[:time_entry][:issue_id].to_i			
			@materialEntries.comments =  params[:time_entry][:comments]
			@materialEntries.activity_id =  params[:time_entry][:activity_id].to_i
			@materialEntries.spent_on = params[:time_entry][:spent_on]
			@materialEntries.selling_price = params[:product_sell_price]
			@materialEntries.uom_id = params[:uom_id]			
		end
		
		def set_filter_session
			if params[:spent_type].blank?
				session[:timelog] = {:spent_type => "T"}
			else
				session[:timelog][:spent_type] = params[:spent_type]
			end
		end
		
		def find_time_entries
			if session[:timelog][:spent_type] === "T"
				@time_entries = TimeEntry.where(:id => params[:id] || params[:ids]).
					preload(:project => :time_entry_activities).
					preload(:user).to_a

				raise ActiveRecord::RecordNotFound if @time_entries.empty?
				raise Unauthorized unless @time_entries.all? {|t| t.editable_by?(User.current)}
				@projects = @time_entries.collect(&:project).compact.uniq
				@project = @projects.first if @projects.size == 1
			else
				@time_entry = TimeEntry.new
				materialEntry = WkMaterialEntry.find(params[:id])
				@time_entry.id = materialEntry.id
				@project = materialEntry.project
			end
		rescue ActiveRecord::RecordNotFound
			render_404
		end
		
		def find_time_entry
			if session[:timelog][:spent_type] === "T"
				@time_entry = TimeEntry.find(params[:id])
				@project = @time_entry.project
			else
				@time_entry = TimeEntry.first
				materialEntry = WkMaterialEntry.find(params[:id])
				@time_entry.id = materialEntry.id
				@project = materialEntry.project
			end   			
		  rescue ActiveRecord::RecordNotFound
			render_404
	    end
		
		def check_editability
			wktime_helper = Object.new.extend(WktimeHelper)
			if session[:timelog][:spent_type] === "T"
				unless @time_entry.editable_by?(User.current)
				  render_403
				  return false
				end
			else
				return wktime_helper.showInventory
			end
		end

		def destroy
			wktime_helper = Object.new.extend(WktimeHelper)
			errMsg = ""
			if session[:timelog][:spent_type] === "T"
				destroyed = TimeEntry.transaction do
					@time_entries.each do |t|
						status = wktime_helper.getTimeEntryStatus(t.spent_on, t.user_id)	
						if !status.blank? && ('a' == status || 's' == status || 'l' == status)			
							errMsg = "#{l(:error_time_entry_delete)}"
						end
						if errMsg.blank?
							unless (t.destroy && t.destroyed?)  
								raise ActiveRecord::Rollback
							end
						end
					end
				end
				respond_to do |format|
					format.html {
						if errMsg.blank?
							if destroyed
								flash[:notice] = l(:notice_successful_delete)
							else
								flash[:error] = l(:notice_unable_delete_time_entry)
							end
						else
							flash[:error] = errMsg
						end
						redirect_back_or_default project_time_entries_path(@projects.first)
					}
					format.api  {
						if destroyed
							render_api_ok
						else
							render_validation_errors(@time_entries)
						end
					}
				end
			else				
				destroyed = WkMaterialEntry.transaction do
					begin
					@materialEntries = WkMaterialEntry.find(params[:id].to_i) unless params[:id].blank?
					@time_entry.project_id = @materialEntries.project_id
					if @materialEntries.invoice_item_id.blank?
						inventoryItemObj = WkInventoryItem.find(@materialEntries.inventory_item_id)
						inventoryItemObj.available_quantity = inventoryItemObj.available_quantity + @materialEntries.quantity
						inventoryItemObj.save						
						@materialEntries.destroy
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
				respond_to do |format|
					format.html { 
					unless errMsg.blank?
						flash[:error] = errMsg
						redirect_back_or_default project_time_entries_path(@time_entry.project)
					else
						flash[:notice] = l(:notice_successful_update)
						redirect_back_or_default project_time_entries_path(@time_entry.project)
					end
					 
					}
				end
			end		
		end
	end
	end
end

	class Paginator
      attr_reader :item_count, :per_page, :page, :page_param

      def initialize(*args)
        if args.first.is_a?(ActionController::Base)
          args.shift
          ActiveSupport::Deprecation.warn "Paginator no longer takes a controller instance as the first argument. Remove it from #new arguments."
        end
        item_count, per_page, page, page_param = *args

        @item_count = item_count
        @per_page = per_page
        page = (page || 1).to_i
        if page < 1
          page = 1
        end
        @page = page
        @page_param = page_param || :page
      end

      def offset
        (page - 1) * per_page
      end

      def first_page
        if item_count > 0
          1
        end
      end

      def previous_page
        if page > 1
          page - 1
        end
      end

      def next_page
        if last_item < item_count
          page + 1
        end
      end

      def last_page
        if item_count > 0
          (item_count - 1) / per_page + 1
        end
      end

      def multiple_pages?
        per_page < item_count
      end

      def first_item
        item_count == 0 ? 0 : (offset + 1)
      end

      def last_item
        l = first_item + per_page - 1
        l > item_count ? item_count : l
      end

      def linked_pages
        pages = []
        if item_count > 0
          pages += [first_page, page, last_page]
          pages += ((page-2)..(page+2)).to_a.select {|p| p > first_page && p < last_page}
        end
        pages = pages.compact.uniq.sort
        if pages.size > 1
          pages
        else
          []
        end
      end

      def items_per_page
        ActiveSupport::Deprecation.warn "Paginator#items_per_page will be removed. Use #per_page instead."
        per_page
      end

      def current
        ActiveSupport::Deprecation.warn "Paginator#current will be removed. Use .offset instead of .current.offset."
        self
      end
    end

