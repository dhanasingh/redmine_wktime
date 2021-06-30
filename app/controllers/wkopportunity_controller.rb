class WkopportunityController < WkcrmController
  unloadable
  menu_item :wklead
  include WktimeHelper
	include WkopportunityHelper
  accept_api_auth :index

  def index
		sort_init 'updated_at', 'desc'

		sort_update 'opportunity_name' => "#{WkOpportunity.table_name}.name",
					'parent_type' => "#{WkOpportunity.table_name}.parent_type",
					'sales_stage' => "E.name",
					'amount' => "#{WkOpportunity.table_name}.amount",
					'close_date' => "#{WkOpportunity.table_name}.close_date",
					'assigned_user_id' => "CONCAT(U.firstname, U.lastname)",
					'updated_at' => "#{WkOpportunity.table_name}.updated_at"

		set_filter_session
		retrieve_date_range
		oppName = session[controller_name].try(:[], :oppname)
		accId = session[controller_name].try(:[], :account_id)

		oppDetails = WkOpportunity.joins("LEFT JOIN (SELECT id, firstname, lastname FROM users) AS U ON wk_opportunities.assigned_user_id = U.id
			LEFT JOIN wk_crm_enumerations AS E on wk_opportunities.sales_stage_id = E.id")

		filterSql = ""
		filterHash = Hash.new
		unless @from.blank? || @to.blank?
			filterSql = filterSql + " wk_opportunities.created_at between :from AND :to"
			filterHash = {:from => getFromDateTime(@from), :to => getToDateTime(@to)}
		end
		unless oppName.blank?
			filterSql = filterSql + " AND" unless filterSql.blank?
			filterSql = filterSql + " LOWER(wk_opportunities.name) like LOWER(:name)"
			filterHash[:name] = "%#{oppName}%"
		end
		unless accId.blank?
			filterSql = filterSql + " AND" unless filterSql.blank?
			filterSql = filterSql + " parent_id = :parent_id "
			filterHash[:parent_id] = accId.to_i
			filterHash[:parent_type] = 'WkAccount'
		end
		unless filterHash.blank? || filterSql.blank?
			oppDetails = oppDetails.where(filterSql, filterHash)
		end
		oppDetails = oppDetails.reorder(sort_clause)
		respond_to do |format|
			format.html do
				formPagination(oppDetails)
			  render :layout => !request.xhr?
			end
			format.api do
				@opportunity = oppDetails
			end
			format.csv do
				headers = { name: l(:field_name), related: l(:label_relates_to), sales_stage: l(:label_txn_sales_stage), amount: l(:field_amount), closeDate: l(:label_expected_date_to_close_project), assignee: l(:field_assigned_to), modified: l(:label_modified) }
				data = oppDetails.map do |e|
					sales_stage = e.sales_stage_id.blank? ? "" : getSaleStageHash[e.sales_stage_id]
					{ name: e.name, related: relatedHash[e.parent_type], sales_stage: sales_stage, amount: ((e&.currency || '')+" "+e.amount.round(2).to_s), closeDate: e.close_date.localtime.strftime("%Y-%m-%d"), assignee: (e&.assigned_user&.name(:firstname_lastname) || ''), modified: e.updated_at.localtime.strftime("%Y-%m-%d") }
				end
				respond_to do |format|
					format.csv {
						send_data(csv_export({headers: headers, data: data}), type: 'text/csv; header=present', filename: 'opportunity.csv')
					}
				end
			end
		end
  end
  
    def edit
		@oppEditEntry = nil
		unless params[:opp_id].blank?
			@oppEditEntry = WkOpportunity.where(:id => params[:opp_id].to_i)
		end
		isError = params[:isError].blank? ? false : to_boolean(params[:isError])
		if !$tempOpportunity.blank?  && isError
			@oppEditEntry = $tempOpportunity
		end
    end
  
    def update
		errorMsg = nil
		oppEntry = nil
		@tempoppEntry ||= Array.new
		unless params[:opp_id].blank?
			oppEntry = WkOpportunity.find(params[:opp_id].to_i)
			oppEntry.updated_by_user_id = User.current.id
		else
			oppEntry = WkOpportunity.new
			oppEntry.created_by_user_id = User.current.id
		end
		oppEntry.name = params[:opp_name]
		oppEntry.currency = params[:currency]
		oppEntry.close_date = Time.parse(params[:expected_close_date])
		oppEntry.amount = params[:opp_amount]
		oppEntry.assigned_user_id = params[:assigned_user_id]
		oppEntry.opportunity_type_id = params[:opp_type]
		oppEntry.sales_stage_id = params[:sales_stage]
		oppEntry.lead_source_id = params[:lead_source_id]
		oppEntry.probability = params[:opp_probability]
		oppEntry.next_step = params[:opp_next_step]
		oppEntry.description = params[:opp_description]
		oppEntry.parent_id = params[:related_parent]
		oppEntry.parent_type = params[:related_to].to_s
		notify = params[:opp_id].present? && oppEntry.sales_stage_id_changed? 
		unless oppEntry.valid?
			@tempoppEntry << oppEntry
			$tempOpportunity = @tempoppEntry
			errorMsg = oppEntry.errors.full_messages.join("<br>")
		else			
			oppEntry.save()
			$tempOpportunity = nil 
		end
		
		if errorMsg.blank? && notify && WkNotification.notify('opportunityStatusChanged')
			WkOpportunity.opportunity_notification(oppEntry)
		end
		
		if errorMsg.blank?
			redirect_to :controller => 'wkopportunity',:action => 'index' , :tab => 'wkopportunity'
			flash[:notice] = l(:notice_successful_update)
		else
			flash[:error] = errorMsg 
			redirect_to :controller => 'wkopportunity',:action => 'edit', :isError => true
		end	
    end
  
    def destroy
		trans = WkOpportunity.find(params[:opp_id].to_i).destroy
		flash[:notice] = l(:notice_successful_delete)
		delete_documents(params[:opp_id])
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end
  
  
    def set_filter_session
		filters = [:period_type, :oppname, :account_id, :period, :from, :to]
		super(filters, {:from => @from, :to => @to})
    end
   	
	def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		@opportunity = entries.limit(@limit).offset(@offset)
	end
	
	def setLimitAndOffset		
		if api_request?
			@offset, @limit = api_offset_and_limit
			if !params[:limit].blank?
				@limit = params[:limit]
			end
			if !params[:offset].blank?
				@offset = params[:offset]
			end
		else
			@entry_pages = Paginator.new @entry_count, per_page_option, params['page']
			@limit = @entry_pages.per_page
			@offset = @entry_pages.offset
		end	
	end

end
