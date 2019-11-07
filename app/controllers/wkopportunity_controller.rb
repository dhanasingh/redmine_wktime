class WkopportunityController < WkcrmController
  unloadable
  include WktimeHelper
  helper_method :sort_column, :sort_direction

    def index
		set_filter_session
		retrieve_date_range
		oppName = session[:wkopportunity][:oppname]
		accId = session[:wkopportunity][:account_id]
		oppDetails = nil
		filterSql = ""
		filterHash = Hash.new
		unless @from.blank? || @to.blank?
			filterSql = filterSql + " wk_opportunities.created_at between :from AND :to"
			filterHash = {:from => getFromDateTime(@from), :to => getToDateTime(@to)}  
		end
		unless oppName.blank?
			filterSql = filterSql + " AND" unless filterSql.blank?
			filterSql = filterSql + " LOWER(name) like LOWER(:name)"
			filterHash[:name] = "%#{oppName}%"
		end
		unless accId.blank?
			filterSql = filterSql + " AND" unless filterSql.blank?
			filterSql = filterSql + " parent_id = :parent_id "
			filterHash[:parent_id] = accId.to_i
			filterHash[:parent_type] = 'WkAccount'
		end
		unless filterHash.blank? || filterSql.blank?
			oppDetails = WkOpportunity.where(filterSql, filterHash)
		else
			oppDetails = WkOpportunity.all
		end
		
		formPagination(oppDetails)
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
		unless oppEntry.valid?
			@tempoppEntry << oppEntry
			$tempOpportunity = @tempoppEntry
			errorMsg = oppEntry.errors.full_messages.join("<br>")
		else			
			oppEntry.save()
			$tempOpportunity = nil 
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
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end
  
  
    def set_filter_session
        if params[:searchlist].blank? && session[:wkopportunity].nil?
			session[:wkopportunity] = {:period_type => params[:period_type],:period => params[:period],	:from => @from, :to => @to, :oppname => params[:oppname], :account_id => params[:account_id] }
		elsif params[:searchlist] =='wkopportunity'
			session[:wkopportunity][:period_type] = params[:period_type]
			session[:wkopportunity][:period] = params[:period]
			session[:wkopportunity][:from] = params[:from]
			session[:wkopportunity][:to] = params[:to]
			session[:wkopportunity][:oppname] = params[:oppname]
			session[:wkopportunity][:account_id] = params[:account_id]
		end
		
    end
   	
	def formPagination(entries)
		helperColumn = []
		relatedHash.each {|key, value| helperColumn.push("select '#{key}' as parent_type, '#{value}' as related_hash")}
		helperColumn = helperColumn.join(" union ")
		@entry_count = entries.count
        setLimitAndOffset()
		@opportunity = entries.joins("LEFT JOIN wk_crm_enumerations ON wk_crm_enumerations.id = wk_opportunities.sales_stage_id").joins("LEFT JOIN users ON users.id = wk_opportunities.assigned_user_id").joins("JOIN (#{helperColumn}) AS related_types ON wk_opportunities.parent_type = related_types.parent_type").order(sort_column + " " + sort_direction + ", name asc").limit(@limit).offset(@offset)
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

	def sort_column
		allColumns = WkOpportunity.column_names()
		allColumns.push("users.lastname", "wk_opportunities.updated_at", "wk_crm_enumerations.name", "related_hash")
		allColumns.include?(params[:sort]) ? params[:sort] : "wk_opportunities.updated_at"
	end

	def sort_direction
		%w[asc desc].include?(params[:direction]) ? params[:direction] : "asc"
	end
end
