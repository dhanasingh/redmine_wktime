class WkgltransactionController < WkaccountingController
  unloadable
   def index
	    set_filter_session
        retrieve_date_range
		@ledgers = WkLedger.pluck(:name, :id)
		ledgerId = session[:wkgltransaction][:ledger_id]
		if !@from.blank? && !@to.blank?
			transaction = WkGlTransaction.includes(:transaction_details).where(:trans_date => @from .. @to)
		else
			transaction = WkGlTransaction.includes(:transaction_details)#.where( :wk_gl_transaction_details => { :ledger_id => ledgerId })
		end
		unless ledgerId.blank?
			transaction = transaction.where( :wk_gl_transaction_details => { :ledger_id => ledgerId })
		end
		formPagination(transaction)
		@totalTransAmt = @transEntries.where( :wk_gl_transaction_details => { :detail_type => "d" }).sum("wk_gl_transaction_details.amount")
   end
   
    def edit
		@transDetails = nil
		@ledgers = WkLedger.pluck(:name, :id)
		unless params[:txn_id].blank? 
			@transEntry = WkGlTransaction.where(:id => params[:txn_id])
			@transDetails = WkGlTransactionDetail.where(:gl_transaction_id => params[:txn_id])
		end
    end
   
    def update
		errorMsg = nil
		wkgltransaction = nil
		wktxnDetail = nil
		arrId = []
		if params[:gl_transaction_id].blank?
			wkgltransaction = WkGlTransaction.new
		else
			wkgltransaction = WkGlTransaction.find(params[:gl_transaction_id].to_i)
		end
		wkgltransaction.trans_type = params[:txn_type]
		wkgltransaction.trans_date = params[:date]
		wkgltransaction.comment = params[:txn_cmt]
		unless wkgltransaction.valid?
			errorMsg = wkgltransaction.errors.full_messages.join("<br>")
		end
		Rails.logger.info("============ errorMsg #{errorMsg} ======================")
		if errorMsg.blank?
			for i in 1..params[:txntotalrow].to_i			
				if params["txn_id#{i}"].blank?
					wktxnDetail = WkGlTransactionDetail.new
				else
					wktxnDetail = WkGlTransactionDetail.find(params["txn_id#{i}"].to_i)
					
				end
				wktxnDetail.ledger_id = params["txn_particular#{i}"]
				if params["txn_debit#{i}"].blank?
					wktxnDetail.detail_type = 'c'
					wktxnDetail.amount = params["txn_credit#{i}"]
				else
					wktxnDetail.detail_type = 'd'
					wktxnDetail.amount = params["txn_debit#{i}"]
				end
				wktxnDetail.currency = Setting.plugin_redmine_wktime['wktime_currency']
				unless wktxnDetail.valid? 		
					errorMsg = errorMsg.blank? ? wktxnDetail.errors.full_messages.join("<br>") : wktxnDetail.errors.full_messages.join("<br>") + "<br/>" + errorMsg
				else
					if i == 1 
						wkgltransaction.save()
					end
					wktxnDetail.gl_transaction_id = wkgltransaction.id
					wktxnDetail.save()
					arrId << wktxnDetail.id
				end

			end
			unless arrId.blank?
				WkGlTransactionDetail.where(:gl_transaction_id => wkgltransaction.id).where.not(:id => arrId).delete_all()
			end
		end
		if errorMsg.blank?
		    redirect_to :controller => 'wkgltransaction',:action => 'index' , :tab => 'wkgltransaction'
		    flash[:notice] = l(:notice_successful_update)
		else
			flash[:error] = errorMsg #wkaccount.errors.full_messages.join("<br>")
		    redirect_to :controller => 'wkgltransaction',:action => 'edit'
		end
    end
	
	def destroy
		trans = WkGlTransaction.find(params[:txn_id].to_i).destroy
		flash[:notice] = l(:notice_successful_delete)
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end
  
   def set_filter_session
        if params[:searchlist].blank? && session[:wkgltransaction].nil?
			session[:wkgltransaction] = {:period_type => params[:period_type],:period => params[:period],	:ledger_id =>	params[:txn_ledger],	                      
								   :from => @from, :to => @to}
		elsif params[:searchlist] =='wkgltransaction'
			session[:wkgltransaction][:period_type] = params[:period_type]
			session[:wkgltransaction][:period] = params[:period]
			session[:wkgltransaction][:from] = params[:from]
			session[:wkgltransaction][:to] = params[:to]
			session[:wkgltransaction][:ledger_id] = params[:txn_ledger]
		end
		
    end
   
   # Retrieves the date range based on predefined ranges or specific from/to param dates
	def retrieve_date_range
		@free_period = false
		@from, @to = nil, nil
		period_type = session[:wkgltransaction][:period_type]
		period = session[:wkgltransaction][:period]
		fromdate = session[:wkgltransaction][:from]
		todate = session[:wkgltransaction][:to]
		
		if (period_type == '1' || (period_type.nil? && !period.nil?)) 
		    case period.to_s
			  when 'today'
				@from = @to = Date.today
			  when 'yesterday'
				@from = @to = Date.today - 1
			  when 'current_week'
				@from = getStartDay(Date.today - (Date.today.cwday - 1)%7)
				@to = @from + 6
			  when 'last_week'
				@from =getStartDay(Date.today - 7 - (Date.today.cwday - 1)%7)
				@to = @from + 6
			  when '7_days'
				@from = Date.today - 7
				@to = Date.today
			  when 'current_month'
				@from = Date.civil(Date.today.year, Date.today.month, 1)
				@to = (@from >> 1) - 1
			  when 'last_month'
				@from = Date.civil(Date.today.year, Date.today.month, 1) << 1
				@to = (@from >> 1) - 1
			  when '30_days'
				@from = Date.today - 30
				@to = Date.today
			  when 'current_year'
				@from = Date.civil(Date.today.year, 1, 1)
				@to = Date.civil(Date.today.year, 12, 31)
	        end
		elsif period_type == '2' || (period_type.nil? && (!fromdate.nil? || !todate.nil?))
		    begin; @from = fromdate.to_s.to_date unless fromdate.blank?; rescue; end
		    begin; @to = todate.to_s.to_date unless todate.blank?; rescue; end
		    @free_period = true
		else
		  # default
		  # 'current_month'		
			@from = Date.civil(Date.today.year, Date.today.month, 1)
			@to = (@from >> 1) - 1
	    end    
		
		@from, @to = @to, @from if @from && @to && @from > @to

	end
	
	def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		@transEntries = entries.order(:id).limit(@limit).offset(@offset)
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
