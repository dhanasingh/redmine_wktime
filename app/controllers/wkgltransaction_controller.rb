# ERPmine - ERP for service industry
# Copyright (C) 2011-2020  Adhi software pvt ltd
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

  include WkgltransactionHelper
	accept_api_auth :index, :edit, :update

	def index
		sort_init 'trans_date', 'desc'
		sort_update 'trans_date' => "trans_date",
								'trans_type' => "trans_type"
		@ledgers = WkLedger.order(:name).pluck(:name, :id)
		if params[:is_summary_edit] != 'true'
			set_filter_session
			retrieve_date_range
			@selectedLedger = nil
			@ledgerId = session[controller_name].try(:[], :txn_ledger)
			transactionType = session[controller_name].try(:[], :trans_type)
			@summaryTransaction = session[controller_name].try(:[], :summary_trans)
		else
			@summaryTransaction = params[:summary_by].to_s
			@from = params[:from]
			@to = params[:to]
			transactionType = session[controller_name].try(:[], :trans_type)
			@ledgerId = params[:txn_ledger]
			@free_period = true
		end
		if @summaryTransaction != 'days'
			transaction = WkGlTransaction.joins(:transaction_details)
		else
			transaction = WkGlTransaction.includes(:transaction_details)
		end
		if !@from.blank? && !@to.blank?
			transaction = transaction.where(:trans_date => @from .. @to)
		end
		unless transactionType.blank?
			transaction = transaction.where(:trans_type => transactionType)
		end
		@totalTransAmt = nil
		@totalType = nil
		unless @ledgerId.blank?
			@selectedLedger = WkLedger.find(@ledgerId)
			transaction = transaction.where( :wk_gl_transaction_details => { :ledger_id => @ledgerId })
			if @summaryTransaction != 'days'
				if @summaryTransaction == 'month'
					summary_by = getDatePart('trans_date','year')+', tmonth'
					alice_name = getDatePart('trans_date','year', 'tyear')+', tmonth'
				elsif @summaryTransaction == 'week'
					summary_by = 'tyear, tweek'
					alice_name = 'tyear, tweek'
				else @summaryTransaction == 'year'
					summary_by = getDatePart('trans_date','year')
					alice_name = getDatePart('trans_date','year', 'tyear')
				end

				trans_date = transaction.minimum(:trans_date) - 1 unless transaction.minimum(:trans_date).blank?
				@transDate = @from.blank? ? trans_date : @from -1
				sort_direction = params[:sort].present? ? (params[:sort].split(':')[1] || "asc") : "desc"

				order_val = alice_name.split(',').map{|item| (item.split('as').last).strip().to_s + " #{sort_direction}"}
				transaction = transaction.group(" #{summary_by}, detail_type, ledger_id")
					.select(" #{alice_name}, detail_type, ledger_id, sum(amount) as amount").order("#{order_val.join(',')}")
				@summaryHash = Hash.new
				debitTotal = 0
				creditTotal = 0
				closeBalTotal = 0
				closeBal = 0
				transaction.each do |entry|
					if (entry.tyear > 0 && ((@summaryTransaction == 'week' && entry.tweek > 0) || (@summaryTransaction == 'month' && entry.tmonth > 0))) || entry.tyear > 0
						if @summaryTransaction == 'month'
							summary = (Date::MONTHNAMES[entry.tmonth].to_s) + "_"
							beginning_date= Date.civil(entry.tyear, entry.tmonth, 1)
							end_date = beginning_date.end_of_month
						elsif @summaryTransaction == 'week'
							entry.tyear = Date.valid_commercial?(entry.tyear, entry.tweek, 1) ? entry.tyear : entry.tyear - 1 if entry.tweek == 53
							summary = (entry.tweek).to_s + "_week_"
							beginning_date = Date.commercial(entry.tyear, entry.tweek, 1)
							end_date = Date.commercial(entry.tyear, entry.tweek, 7)
						else
							summary = ""
							beginning_date= Date.civil(entry.tyear, 1)
							end_date = beginning_date.end_of_year
						end
						key = (summary).to_s + (entry.tyear).to_s
						@summaryHash[key] = Hash.new if @summaryHash[key].blank?
						@summaryHash[key][:DT] = entry.amount + (@summaryHash[key][:DT] || 0) if entry.detail_type == 'd'
						@summaryHash[key][:CT] = entry.amount + (@summaryHash[key][:CT] || 0) if entry.detail_type == 'c'
						@summaryHash[key][:beginning_date] = beginning_date
						@summaryHash[key][:end_date] = end_date
						@summaryHash[key][:ledger_id] = entry.ledger_id
					end
				end

				dup_summary = sort_direction == "desc" ? @summaryHash.to_a.reverse.to_h : @summaryHash
				@summaryHashFirstKey = dup_summary.keys.first
				dup_summary.each do |key, value|
					getSummeryamount(key, value)
					@summaryHash[key][:CB] = @closeBal
				end
			else
				formPagination(transaction.reorder(sort_clause))
				isSubCr = isSubtractCr(@selectedLedger.ledger_type)
				totalDbTransAmt = @transEntries.where( :wk_gl_transaction_details => { :detail_type => "d" }).sum("wk_gl_transaction_details.amount")
				totalCrTransAmt = @transEntries.where( :wk_gl_transaction_details => { :detail_type => "c" }).sum("wk_gl_transaction_details.amount")
				@totalTransAmt = isSubCr ? totalDbTransAmt - totalCrTransAmt : totalCrTransAmt - totalDbTransAmt
				if (isSubCr && @totalTransAmt > 0) || (!isSubCr && @totalTransAmt < 0)
					@totalType = 'dr'
				else
					@totalType = 'cr'
				end
			end
		else
			formPagination(transaction.reorder(sort_clause))
		end
		transaction
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
		set_transaction_session
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
					if params["txn_id_#{i}"].blank?
						wktxnDetail = WkGlTransactionDetail.new
					else
						wktxnDetail = WkGlTransactionDetail.find(params["txn_id_#{i}"].to_i)

					end
					wktxnDetail.ledger_id = params["txn_particular_#{i}"]
					if (params["txn_debit_#{i}"].blank? || params["txn_debit_#{i}"].to_f == 0) && (params["txn_credit_#{i}"].blank? || params["txn_credit_#{i}"].to_f == 0)
						next
					elsif params["txn_debit_#{i}"].blank? || params["txn_debit_#{i}"].to_f == 0
						wktxnDetail.detail_type = 'c'
						wktxnDetail.amount = params["txn_credit_#{i}"]
					else
						wktxnDetail.detail_type = 'd'
						wktxnDetail.amount = params["txn_debit_#{i}"]
					end
					wktxnDetail.currency = Setting.plugin_redmine_wktime['wktime_currency']
					unless wktxnDetail.valid?
						errorMsg = errorMsg.blank? ? wktxnDetail.errors.full_messages.join("<br>") : wktxnDetail.errors.full_messages.join("<br>") + "<br/>" + errorMsg
					else
						if i == 1
							wkgltransaction.save()
							#for attachment save
							errorMsg = save_attachments(wkgltransaction.id) if params[:attachments].present?
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
		respond_to do |format|
			format.html {
				if errorMsg.blank?
					action_name = params[:gltransaction_save_continue].blank? ? "index" : "edit"
						redirect_to :controller => 'wkgltransaction', :action => action_name, :tab => 'wkgltransaction'
					$temptxnDetail = nil
					$tempTransaction = nil
						flash[:notice] = l(:notice_successful_update)
				else
					flash[:error] = errorMsg
						redirect_to :controller => 'wkgltransaction',:action => 'edit', :isError => true
				end
			}
			format.api{
				if errorMsg.blank?
					render :plain => errorMsg, :layout => nil
				else
					@error_messages = errorMsg.split('\n')
					render :template => 'common/error_messages', :format => [:api], :status => :unprocessable_entity, :layout => nil
				end
			}
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
				ledgerId = params["txn_particular_#{i}"]
				ret = ledgerHash[ledgerId.to_i] == 'CS' || ledgerHash[ledgerId.to_i] == 'BA' ? true : false
				break if !ret
			end

		when 'P', 'R'
			isledger = false
			for i in 1..params[:txntotalrow].to_i
				ledgerId = params["txn_particular_#{i}"]
				if ledgerHash[ledgerId.to_i] == 'CS' || ledgerHash[ledgerId.to_i] == 'BA'
					isledger = true
					ret =  params["txn_debit_#{i}"].blank? ? true : false if params[:txn_type] == 'P'
					ret =  !params["txn_debit_#{i}"].blank? ? true : false if params[:txn_type] == 'R'
				end
				break if !ret
			end
			ret = isledger if ret

		when 'PR'
			for i in 1..params[:txntotalrow].to_i
				ledgerId = params["txn_particular_#{i}"]
				ret = ledgerHash[ledgerId.to_i] == 'PA' ? true : false  if !params["txn_debit_#{i}"].blank?
				ret = ledgerHash[ledgerId.to_i] == 'CS' || ledgerHash[ledgerId.to_i] == 'BA' || ledgerHash[ledgerId.to_i] == 'SC' || ledgerHash[ledgerId.to_i] == 'SD'  ? true : false  if params["txn_debit_#{i}"].blank?
				break if !ret
			end

		when 'S'
			for i in 1..params[:txntotalrow].to_i
				ledgerId = params["txn_particular_#{i}"]
				ret = ledgerHash[ledgerId.to_i] == 'SA' ? true : false  if params["txn_debit_#{i}"].blank?
				ret = ledgerHash[ledgerId.to_i] == 'CS' || ledgerHash[ledgerId.to_i] == 'BA' || ledgerHash[ledgerId.to_i] == 'SC' || ledgerHash[ledgerId.to_i] == 'SD'  ? true : false  if !params["txn_debit_#{i}"].blank?
				break if !ret
			end

		when 'CN'
			for i in 1..params[:txntotalrow].to_i
				ledgerId = params["txn_particular_#{i}"]
				ret = ledgerHash[ledgerId.to_i] != 'CS' || ledgerHash[ledgerId.to_i] != 'BA' ? true : false  if !params["txn_debit_#{i}"].blank?
				ret = ledgerHash[ledgerId.to_i] == 'CS' || ledgerHash[ledgerId.to_i] == 'BA' || ledgerHash[ledgerId.to_i] == 'SC' || ledgerHash[ledgerId.to_i] == 'SD'  ? true : false  if params["txn_debit_#{i}"].blank?
				break if !ret
			end

		when 'DN'
			for i in 1..params[:txntotalrow].to_i
				ledgerId = params["txn_particular_#{i}"]
				ret = ledgerHash[ledgerId.to_i] != 'CS' || ledgerHash[ledgerId.to_i] != 'BA' ? true : false  if params["txn_debit_#{i}"].blank?
				ret = ledgerHash[ledgerId.to_i] == 'CS' || ledgerHash[ledgerId.to_i] == 'BA' || ledgerHash[ledgerId.to_i] == 'SC' || ledgerHash[ledgerId.to_i] == 'SD'  ? true : false  if !params["txn_debit_#{i}"].blank?
				break if !ret
			end
		end

		for i in 1..params[:txntotalrow].to_i
			txnDebitTotal = txnDebitTotal + params["txn_debit_#{i}"].to_f if !params["txn_debit_#{i}"].blank?
			txnCreditTotal = txnCreditTotal + params["txn_debit_#{i}"].to_f if !params["txn_debit_#{i}"].blank?
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
				if params["txn_id_#{i}"].blank?
					wktxnDetail = WkGlTransactionDetail.new
				else
					wktxnDetail = WkGlTransactionDetail.find(params["txn_id_#{i}"].to_i)

				end
				wktxnDetail.ledger_id = params["txn_particular_#{i}"]
				if params["txn_debit_#{i}"].blank?
					wktxnDetail.detail_type = 'c'
					wktxnDetail.amount = params["txn_credit_#{i}"]
				else
					wktxnDetail.detail_type = 'd'
					wktxnDetail.amount = params["txn_debit_#{i}"]
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
		filters = [:period_type, :period, :txn_ledger, :from, :to, :trans_type, :summary_trans, :show_chart]
		super(filters, {:summary_trans => "days"})
	end

   # Retrieves the date range based on predefined ranges or specific from/to param dates
	def retrieve_date_range
		@free_period = false
		@from, @to = nil, nil
		period_type = session[controller_name].try(:[], :period_type)
		period = session[controller_name].try(:[], :period)
		fromdate = session[controller_name].try(:[], :from)
		todate = session[controller_name].try(:[], :to)

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
		@transEntries = entries.limit(@limit).offset(@offset)
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

	def set_transaction_session
		session[controller_name][:start_date] = params[:date]
		session[controller_name][:txn_type] = params[:txn_type]
		session[controller_name][:ledger_id1] = params[:txn_particular_1]
		session[controller_name][:ledger_id2] = params[:txn_particular_2]
	end

	def export
		respond_to do |format|
			transactionEntries = index
			format.csv {
				send_data(csv_format_conversion(transactionEntries), :type => 'text/csv; header=present', :filename => 'gltransaction.csv')
			}
		end
	end

  def graph
    data = get_Ledger_Graph_data
    if data
      render :json => data
    else
      render_404
    end
  end

end
