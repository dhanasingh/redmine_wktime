class WkopportunityController < WkcrmController

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
		sales_stage = session[controller_name].try(:[], :sales_stage)
		filter_type = session[controller_name].try(:[], :polymorphic_filter)
		contact_id = session[controller_name].try(:[], :contact_id)
		account_id = session[controller_name].try(:[], :account_id)
		oppDetails = WkOpportunity.joins("
			LEFT JOIN(
				SELECT MAX(status_date) AS status_date, status_for_id
				FROM wk_statuses
				WHERE status_for_type = 'WkOpportunity' "+get_comp_condition('wk_statuses') + "
				GROUP BY status_for_id
			) AS S ON S.status_for_id =  wk_opportunities.id
			LEFT JOIN wk_statuses ON status_for_type = 'WkOpportunity' AND wk_statuses.status_for_id = wk_opportunities.id AND wk_statuses.status_date = S.status_date
			" +get_comp_condition('wk_statuses') + "
			LEFT JOIN users AS U ON wk_opportunities.assigned_user_id = U.id " + get_comp_condition('U') + "
			LEFT JOIN wk_crm_enumerations AS E on S.status_for_id = E.id " + get_comp_condition('E'))
		filterSql = ""
		filterHash = Hash.new
		if (@from.present? || @to.present?) && sales_stage.to_i == 0
			filterSql = filterSql + " wk_opportunities.created_at between :from AND :to"
			filterHash = {:from => getFromDateTime(@from), :to => getToDateTime(@to)}
		elsif (@from.present? || @to.present?) && sales_stage.to_i > 0
			filterSql = filterSql + " wk_statuses.status_date between :from AND :to"
			filterHash = {:from => getFromDateTime(@from), :to => getToDateTime(@to)}
		end
		unless oppName.blank?
			filterSql = filterSql + " AND" unless filterSql.blank?
			filterSql = filterSql + " LOWER(wk_opportunities.name) like LOWER(:name)"
			filterHash[:name] = "%#{oppName}%"
		end

		if filter_type == '3' && account_id.present?
			filterSql = filterSql + " AND" unless filterSql.blank?
			filterSql = filterSql + " wk_opportunities.parent_id = :parent_id AND wk_opportunities.parent_type = :parent_type "
			filterHash[:parent_id] = account_id.to_i
			filterHash[:parent_type] = 'WkAccount'
		elsif filter_type == '3' && account_id.blank?
			filterSql = filterSql + " AND" unless filterSql.blank?
			filterSql = filterSql + " wk_opportunities.parent_type = :parent_type "
			filterHash[:parent_type] = 'WkAccount'
		end
		if filter_type == '2' && contact_id.present?
			filterSql = filterSql + " AND" unless filterSql.blank?
			filterSql = filterSql + " wk_opportunities.parent_id = :parent_id AND wk_opportunities.parent_type = :parent_type"
			filterHash[:parent_id] = contact_id.to_i
			filterHash[:parent_type] = 'WkCrmContact'
		elsif filter_type == '2' && contact_id.blank?
			filterSql = filterSql + " AND" unless filterSql.blank?
			filterSql = filterSql + " wk_opportunities.parent_type = :parent_type "
			filterHash[:parent_type] = 'WkCrmContact'
		end

		unless filterHash.blank? || filterSql.blank?
			oppDetails = oppDetails.where(filterSql, filterHash)
		end

		oppDetails = oppDetails.where("wk_statuses.status = '#{sales_stage.to_i}'") if sales_stage.present? && sales_stage.to_i > 0

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
					sales_stage = get_sales_stage(e).blank? ? "" : getSaleStageHash[get_sales_stage(e)]
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
		oppEntry.close_date =params[:expected_close_date]
		oppEntry.amount = params[:opp_amount]
		oppEntry.assigned_user_id = params[:assigned_user_id]
		oppEntry.opportunity_type_id = params[:opp_type]
		oppEntry.lead_source_id = params[:lead_source_id]
		oppEntry.probability = params[:opp_probability]
		oppEntry.next_step = params[:opp_next_step]
		oppEntry.description = params[:opp_description]
		oppEntry.parent_id = params[:related_parent]
		oppEntry.parent_type = params[:related_to].to_s
		oppEntry.updated_at = Time.now
		notify = params[:opp_id].present? && params[:sales_stage].to_i != get_sales_stage(oppEntry)
		unless oppEntry.valid?
			@tempoppEntry << oppEntry
			$tempOpportunity = @tempoppEntry
			errorMsg = oppEntry.errors.full_messages.join("<br>")
		else
			if params[:opp_id].blank? || params[:opp_id].present? && params[:sales_stage].to_i != get_sales_stage(oppEntry)
				wkstatus = [{status_for_type: "WkOpportunity", status: params[:sales_stage], status_date: Time.now, status_by_id: User.current.id}]
				oppEntry.wkstatus_attributes = wkstatus
			end
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
		filters = [:period_type, :oppname, :account_id, :period, :from, :to, :sales_stage, :contact_id, :account_id, :polymorphic_filter]
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

	def getOrderContactType
		'C'
	end

	def getOrderAccountType
		'A'
	end

	def getAccountDDLbl
		l(:field_account)
	end

	def getAdditionalDD
	end

end
