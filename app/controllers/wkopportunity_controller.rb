class WkopportunityController < WkcrmController
  unloadable
  include WktimeHelper


    def index
		set_filter_session
		retrieve_date_range
		oppName = session[:wkopportunity][:oppname]
		accId = session[:wkopportunity][:account_id]
		oppDetails = nil
		filterSql = ""
		filterHash = Hash.new
		unless @from.blank? || @to.blank?
			filterSql = filterSql + " created_at between :from AND :to"
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
		# if !@from.blank? && !@to.blank? && !oppName.blank? && !accId.blank?
			# oppDetails = WkOpportunity.where(:created_at => @from..@to, :account_id => accId).where("name like ?", "%#{oppName}%")
		# elsif !@from.blank? && !@to.blank? && oppName.blank? && !accId.blank?
			# oppDetails = WkOpportunity.where(:created_at => @from..@to, :account_id => accId)
		# elsif !@from.blank? && !@to.blank? && !oppName.blank? && accId.blank?
			# oppDetails = WkOpportunity.where(:created_at => @from..@to).where("name like ?", "%#{oppName}%")
		# else
			# oppDetails = WkOpportunity.all
		# end
		
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
		@entry_count = entries.count
        setLimitAndOffset()
		@opportunity = entries.order(updated_at: :desc).limit(@limit).offset(@offset)
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
