class WkcontractController < WkbillingController

before_filter :require_login


 def index
		@contract_entries = nil
		sqlwhere = ""
		set_filter_session
		accountId = session[:contract][:account_id]
		projectId	= session[:contract][:project_id]
		
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
			entries = WkContract.all
		else
			entries = WkContract.where(sqlwhere)
		end	
		formPagination(entries)	
    end

    def set_filter_session
        if params[:searchlist].blank? && session[:contract].nil?
			session[:contract] = {:account_id => params[:account_id], :project_id => params[:project_id]}
		elsif params[:searchlist] =='contract'
			session[:contract][:account_id] = params[:account_id]
			session[:contract][:project_id] = params[:project_id]
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
		@contract_entries = entries.limit(@limit).offset(@offset)
	end
	
    def edit
	     @contractEntry = nil
		 unless params[:contract_id].blank?
			@contractEntry = WkContract.find(params[:contract_id])
		 else 
			@contractEntry = @contractEntry
		 end
    end

    def update
		errorMsg = nil
	    if params[:contract_id].blank? || params[:contract_id].to_i == 0
		    wkContract = WkContract.new 
	    else
		    wkContract = WkContract.find(params[:contract_id].to_i)
	    end
		wkContract.project_id = params[:project_id]
		wkContract.account_id = params[:account_id]
		wkContract.contract_number = getPluginSetting('wktime_contract_no_prefix') + params[:contract_number]
		wkContract.start_date = params[:start_date]
		wkContract.end_date = params[:end_date]
		unless wkContract.save
			errorMsg = wkContract.errors.full_messages.join('\n')
		end	
		if errorMsg.blank?
			params[:attachments].each do |attachment_param|
				attachment = Attachment.where('filename = ?', attachment_param[1][:filename]).first
				unless attachment.nil?
				  attachment.container_type = WkContract.name
				  attachment.container_id = wkContract.id
				  attachment.save
				end
			end
			redirect_to :controller => 'wkcontract',:action => 'index' , :tab => 'contract'
		    flash[:notice] = l(:notice_successful_update)
		else
			redirect_to :controller => 'wkcontract',:action => 'edit' , :tab => 'contract'
		    flash[:error] = errorMsg
			
		end
    end	
end
