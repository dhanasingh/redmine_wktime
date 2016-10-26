class WkaccountprojectController < WkbillingController

before_filter :require_login


    def index
		@accountproject = nil
		sqlwhere = ""
		set_filter_session
		accountId = session[:accountproject][:account_id]
		projectId	= session[:accountproject][:project_id]
		
		if accountId.blank? &&  !projectId.blank?
			sqlwhere = "project_id = #{projectId}"
		end
		if !accountId.blank? &&  projectId.blank?
			sqlwhere = "account_id = #{accountId}"
		end
		if !accountId.blank? &&  !projectId.blank?
			sqlwhere = "account_id = #{accountId} and project_id = #{projectId}"
		end
		
		if accountId.blank? && projectId.blank?
			entries = WkAccountProject.all
		else
			entries = WkAccountProject.where(sqlwhere)
		end	
		formPagination(entries)	
    end
	
	def edit
	end
	
	def destroy
	end
  
    def set_filter_session
        if params[:searchlist].blank? && session[:accountproject].nil?
			session[:accountproject] = {:account_id => params[:account_id], :project_id => params[:project_id]}
		elsif params[:searchlist] =='accountproject'
			session[:accountproject][:account_id] = params[:account_id]
			session[:accountproject][:project_id] = params[:project_id]
		end
		
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
	
	def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		@accountproject = entries.limit(@limit).offset(@offset)
	end

end
