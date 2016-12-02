class WkledgerController < WkaccountingController
  unloadable



    def index
		set_filter_session
		ledgerId = session[:wkledger][:ledger_id]
		unless ledgerId.blank?
			ledger = WkLedger.where(:ledger_id => ledgerId )
		else
			ledger = WkLedger.all
		end
		formPagination(ledger)
		@ledgerdd = @ledgers.pluck(:name, :id)
		@totalAmt = @ledgers.sum(:opening_balance)
    end
	
	def edit
		@ledgersDetail = WkLedger.where(:id => params[:ledger_id].to_i)
	end
	
	def update
		wkledger = nil
		errorMsg = nil
		unless params[:ledger_id].blank?
			wkledger = WkLedger.find(params[:ledger_id].to_i)
		else
			wkledger = WkLedger.new
		end
		wkledger.name = params[:name]
		wkledger.ledger_type = params[:ledger_type]
		wkledger.currency = params[:currency]
		wkledger.opening_balance = params[:opening_balance].blank? ? 0 : params[:opening_balance]
		unless wkledger.save()
			errorMsg = wkledger.errors.full_messages.join("<br>")
		end
		if errorMsg.nil?
		    redirect_to :controller => 'wkledger',:action => 'index' , :tab => 'wkledger'
		    flash[:notice] = l(:notice_successful_update)
		else
			flash[:error] = errorMsg 
		    redirect_to :controller => 'wkledger',:action => 'edit'
		end
	end
	
	def destroy
	    desledger = WkLedger.find(params[:ledger_id].to_i).destroy
		flash[:notice] = l(:notice_successful_delete)
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end
	
	def set_filter_session
		if params[:searchlist].blank? && session[:wkledger].nil?
			session[:wkledger] = {:ledger_id =>	params[:txn_ledger]}
		elsif params[:searchlist] =='wkledger'
			session[:wkledger][:ledger_id] = params[:txn_ledger]
		end

	end
	
	def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		@ledgers = entries.order(:id).limit(@limit).offset(@offset)
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
