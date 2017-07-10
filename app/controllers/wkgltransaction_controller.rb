# ERPmine - ERP for service industry
# Copyright (C) 2011-2016  Adhi software pvt ltd
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class WkgltransactionController < WkaccountingController
  unloadable
   def index
	    set_filter_session
        retrieve_date_range
		@selectedLedger = nil
		@ledgers = WkLedger.order(:name).pluck(:name, :id)
		@ledgerId = session[:wkgltransaction][:ledger_id]
		if !@from.blank? && !@to.blank?
			transaction = WkGlTransaction.includes(:transaction_details).where(:trans_date => @from .. @to)
		else
			transaction = WkGlTransaction.includes(:transaction_details)#.where( :wk_gl_transaction_details => { :ledger_id => ledgerId })
		end
		@totalTransAmt = nil
		@totalType = nil
		unless @ledgerId.blank?
			@selectedLedger = WkLedger.find(@ledgerId)
			transaction = transaction.where( :wk_gl_transaction_details => { :ledger_id => @ledgerId })
			formPagination(transaction)
			isSubCr = isSubtractCr(@selectedLedger.ledger_type)
			totalDbTransAmt = @transEntries.where( :wk_gl_transaction_details => { :detail_type => "d" }).sum("wk_gl_transaction_details.amount")
			totalCrTransAmt = @transEntries.where( :wk_gl_transaction_details => { :detail_type => "c" }).sum("wk_gl_transaction_details.amount")
			@totalTransAmt = isSubCr ? totalDbTransAmt - totalCrTransAmt : totalCrTransAmt - totalDbTransAmt
			if (isSubCr && @totalTransAmt > 0) || (!isSubCr && @totalTransAmt < 0)
				@totalType = 'dr'
			else
				@totalType = 'cr'
			end
		else
			formPagination(transaction)
		end
   end
   
    def edit
	    @transEntry = nil
		@transDetails = nil
		@ledgers = WkLedger.order(:name).pluck(:name, :id)
		unless params[:txn_id].blank? && !$temptxnDetail.blank? && !$tempTransaction.blank?
			@transEntry = WkGlTransaction.where(:id => params[:txn_id])
			@transDetails = WkGlTransactionDetail.where(:gl_transaction_id => params[:txn_id])
		end
		isError = params[:isError].blank? ? false : to_boolean(params[:isError])
		if !$temptxnDetail.blank? && !$tempTransaction.blank? && isError
			@transEntry = $tempTransaction
			@transDetails = $temptxnDetail
		end
    end
   
    def update
		errorMsg = nil
		wkgltransaction = nil
		wktxnDetail = nil
		arrId = []
		if validateTransaction
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
			if errorMsg.blank?
				for i in 1..params[:txntotalrow].to_i			
					if params["txn_id#{i}"].blank?
						wktxnDetail = WkGlTransactionDetail.new
					else
						wktxnDetail = WkGlTransactionDetail.find(params["txn_id#{i}"].to_i)
						
					end
					wktxnDetail.ledger_id = params["txn_particular#{i}"]
					if (params["txn_debit#{i}"].blank? || params["txn_debit#{i}"].to_i == 0) && (params["txn_credit#{i}"].blank? || params["txn_credit#{i}"].to_i == 0)
						next
					elsif params["txn_debit#{i}"].blank? || params["txn_debit#{i}"].to_i == 0
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
						wktxnDetail.save() unless wktxnDetail.amount.blank?
						
						arrId << wktxnDetail.id
					end

				end
				unless arrId.blank?
					WkGlTransactionDetail.where(:gl_transaction_id => wkgltransaction.id).where.not(:id => arrId).delete_all()
				end
			end
		else
			
			case params[:txn_type]
			when 'C'
				errorMsg = l(:error_contra_msg)
			when 'P'
				errorMsg = l(:error_payment_msg)
			when 'R'
				errorMsg = l(:error_receipt_msg)
			when 'PR'
				errorMsg = l(:error_purchase_msg)
			when 'S'
				errorMsg = l(:error_sales_msg)
			when 'CN'
				errorMsg = l(:error_cn_msg)
			when 'DN'
				errorMsg = l(:error_dn_msg)
			end
			#errorMsg = l(:label_transaction) + " " + l('activerecord.errors.messages.invalid')
		end
		if errorMsg.blank?
		    redirect_to :controller => 'wkgltransaction',:action => 'index' , :tab => 'wkgltransaction'			
			$temptxnDetail = nil
			$tempTransaction = nil
		    flash[:notice] = l(:notice_successful_update)
		else
			flash[:error] = errorMsg #wkaccount.errors.full_messages.join("<br>")
		    redirect_to :controller => 'wkgltransaction',:action => 'edit', :isError => true
		end
    end
	
	def validateTransaction
		ret = true
		txnDebitTotal = 0
		txnCreditTotal = 0
		@tempwktxnDetail ||= Array.new
		@tempwkgltransaction = nil
		ledgerArray = WkLedger.pluck(:id, :ledger_type)
		ledgerHash = Hash[*ledgerArray.flatten]#.invert 
		case params[:txn_type]
		when 'C' 
			for i in 1..params[:txntotalrow].to_i
				ledgerId = params["txn_particular#{i}"]
				ret = ledgerHash[ledgerId.to_i] == 'CS' || ledgerHash[ledgerId.to_i] == 'BA' ? true : false
				break if !ret			
			end
		
		when 'P', 'R'
			isledger = false
			for i in 1..params[:txntotalrow].to_i
				ledgerId = params["txn_particular#{i}"]
				if ledgerHash[ledgerId.to_i] == 'CS' || ledgerHash[ledgerId.to_i] == 'BA'
					isledger = true
					ret =  params["txn_debit#{i}"].blank? ? true : false if params[:txn_type] == 'P' 
					ret =  !params["txn_debit#{i}"].blank? ? true : false if params[:txn_type] == 'R' 
				end
				break if !ret			
			end	
			ret = isledger if ret
		
		when 'PR'
			for i in 1..params[:txntotalrow].to_i
				ledgerId = params["txn_particular#{i}"]
				ret = ledgerHash[ledgerId.to_i] == 'PA' ? true : false  if !params["txn_debit#{i}"].blank?
				ret = ledgerHash[ledgerId.to_i] == 'CS' || ledgerHash[ledgerId.to_i] == 'BA' || ledgerHash[ledgerId.to_i] == 'SC' || ledgerHash[ledgerId.to_i] == 'SD'  ? true : false  if params["txn_debit#{i}"].blank?				
				break if !ret			
			end			
		
		when 'S'
			for i in 1..params[:txntotalrow].to_i
				ledgerId = params["txn_particular#{i}"]
				ret = ledgerHash[ledgerId.to_i] == 'SA' ? true : false  if params["txn_debit#{i}"].blank?
				ret = ledgerHash[ledgerId.to_i] == 'CS' || ledgerHash[ledgerId.to_i] == 'BA' || ledgerHash[ledgerId.to_i] == 'SC' || ledgerHash[ledgerId.to_i] == 'SD'  ? true : false  if !params["txn_debit#{i}"].blank?
				break if !ret			
			end
		
		when 'CN'
			for i in 1..params[:txntotalrow].to_i
				ledgerId = params["txn_particular#{i}"]
				ret = ledgerHash[ledgerId.to_i] != 'CS' || ledgerHash[ledgerId.to_i] != 'BA' ? true : false  if !params["txn_debit#{i}"].blank?
				ret = ledgerHash[ledgerId.to_i] == 'CS' || ledgerHash[ledgerId.to_i] == 'BA' || ledgerHash[ledgerId.to_i] == 'SC' || ledgerHash[ledgerId.to_i] == 'SD'  ? true : false  if params["txn_debit#{i}"].blank?
				break if !ret			
			end
		
		when 'DN'
			for i in 1..params[:txntotalrow].to_i
				ledgerId = params["txn_particular#{i}"]				 
				ret = ledgerHash[ledgerId.to_i] != 'CS' || ledgerHash[ledgerId.to_i] != 'BA' ? true : false  if params["txn_debit#{i}"].blank?
				ret = ledgerHash[ledgerId.to_i] == 'CS' || ledgerHash[ledgerId.to_i] == 'BA' || ledgerHash[ledgerId.to_i] == 'SC' || ledgerHash[ledgerId.to_i] == 'SD'  ? true : false  if !params["txn_debit#{i}"].blank?				
				break if !ret			
			end
		end
		
		for i in 1..params[:txntotalrow].to_i
			txnDebitTotal = txnDebitTotal + params["txn_debit#{i}"].to_i if !params["txn_debit#{i}"].blank?
			txnCreditTotal = txnCreditTotal + params["txn_debit#{i}"].to_i if !params["txn_debit#{i}"].blank?
		end
		
		if ret
			ret = txnDebitTotal == txnCreditTotal && txnDebitTotal != 0  ? true : false			
		end
		
		#Repopulate the transaction page. Get and set the transaction and transaction detail values.
		unless ret
			if params[:gl_transaction_id].blank?
				wkgltransaction = WkGlTransaction.new
			else
				wkgltransaction = WkGlTransaction.find(params[:gl_transaction_id].to_i)
			end
			wkgltransaction.trans_type = params[:txn_type]
			wkgltransaction.trans_date = params[:date]
			wkgltransaction.comment = params[:txn_cmt]
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
				@tempwktxnDetail << wktxnDetail

			end
			$temptxnDetail = @tempwktxnDetail
			$tempTransaction = wkgltransaction
		end
		
		ret
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
		@transEntries = entries.order(trans_date: :desc).limit(@limit).offset(@offset)
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
