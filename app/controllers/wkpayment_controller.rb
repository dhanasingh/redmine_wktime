# ERPmine - ERP for service industry
# Copyright (C) 2011-2017  Adhi software pvt ltd
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

class WkpaymentController < WkbillingController
  unloadable
  include WkpaymentHelper
  include WkbillingHelper
  
    def index
		@payment_entries = nil
		sqlwhere = ""
		set_filter_session
		retrieve_date_range
		filter_type = session[:payment][:polymorphic_filter]
		contact_id = session[:payment][:contact_id]
		account_id = session[:payment][:account_id]
		
				
		if filter_type == '2' && !contact_id.blank?
			sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " wk_payments.parent_id = '#{contact_id}'  and wk_payments.parent_type = 'WkCrmContact'  "
		elsif filter_type == '2' && contact_id.blank?
			sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " wk_payments.parent_type = 'WkCrmContact'  "
		end
		
		if filter_type == '3' && !account_id.blank?
			sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " wk_payments.parent_id = '#{account_id}'  and wk_payments.parent_type = 'WkAccount'  "
		elsif filter_type == '3' && account_id.blank?
			sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " wk_payments.parent_type = 'WkAccount'  "
		end
		
		if !@from.blank? && !@to.blank?			
			sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " wk_payments.payment_date between '#{@from}' and '#{@to}'  "
		end
		
		if filter_type == '1' 
			entries = WkPayment.includes(:payment_items).where(sqlwhere)
		else
			entries = WkPayment.includes(:payment_items).where(sqlwhere)
		end	
		formPagination(entries)	
		@totalPayAmt = @payment_entries.sum("wk_payment_items.amount")
    end
	
	def edit
		@payment = nil
		@accInvoices = nil
		if !params[:load_payment].blank? && params[:load_payment]
			parentType = params[:related_to]
			parentId = params[:related_parent]
			projectId = params[:project_id]
			if !parentType.blank? && !parentId.blank?
				@accInvoices = WkInvoice.where(:parent_type=> parentType, :parent_id=>parentId)
			end	
		else			
			unless params[:payment_id].blank?
				@payment = WkPayment.find(params[:payment_id].to_i)
				@payemntItem = @payment.payment_items 
				unless params[:is_report].blank? || !to_boolean(params[:is_report])
					@payemntItem = @payemntItem.order(:project_id, :item_type)
					#render :action => 'invreport', :layout => false
				end
			end
		end
	end
	
	def showInvoices
		parentType = params[:related_to]
		parentId = params[:related_parent]
		projectId = params[:project_id]
		@accInvoices = nil
		if !parentType.blank? && !parentId.blank? && !projectId.blank?
			@accInvoices = WkInvoice.where(:parent_type=> parentType, :parent_id=>parent_id)
		end		
	end
	
	def update
		errorMsg = nil
		paymentItem = nil
		unless params["payment_id"].blank?
			@payment = WkPayment.find(params["payment_id"].to_i)
		else
			@payment = WkPayment.new
			@payment.parent_id = params[:related_parent].to_i
			@payment.parent_type = params[:related_to]
			#@payment.gl_transaction_id = 1
		end
		@payment.payment_date = params[:payment_date]
		@payment.payment_type_id = params[:payment_type_id].to_i
		@payment.reference_number = params[:reference_number]
		@payment.description = params[:description]
		totalAmount = 0
		tothash = Hash.new
		totalRow = params[:totalrow].to_i
		if totalRow>0
			@payment.save()
		end
		for i in 1..totalRow
			
			paymentItem = nil
			if !params["payment_item_id#{i}"].blank?	
				paymentItem = WkPaymentItem.find(params["payment_item_id#{i}"].to_i)
			elsif params["amount#{i}"].to_f > 0
					paymentItem = @payment.payment_items.new
			end
			unless paymentItem.blank?
				unless @payment.id.blank?
					glTransactionId = nil
					if isChecked('payment_auto_post_gl')
						transId = paymentItem.gl_transaction.blank? ? nil : paymentItem.gl_transaction.id
						glTransaction = postToGlTransaction('payment', transId, @payment.payment_date, params["amount#{i}"].to_f, params["currency#{i}"], params["invoice_id#{i}"])
						glTransactionId = glTransaction.id unless glTransaction.blank?
					end				
					updatedItem = updatePaymentItem(paymentItem, @payment.id, params["invoice_id#{i}"], params["amount#{i}"].to_f, params["currency#{i}"],glTransactionId ) 
				end	
			end	
		end
		
		# unless @payment.id.blank?
			# totalAmount = @payment.payment_items.sum(:amount)
			# if totalAmount > 0 && isChecked('payment_auto_post_gl')
				# # transId = @payment.gl_transaction.blank? ? nil : @payment.gl_transaction.id
				# # glTransaction = postToGlTransaction('payment', transId, @payment.payment_date, totalAmount, @payment.payment_items[0].currency)
				# # unless glTransaction.blank?
					# # @payment.gl_transaction_id = glTransaction.id
					# # @payment.save
				# # end				
			# end
		# end
		
		if errorMsg.nil? 
			redirect_to :action => 'index' , :tab => 'wkpayment'
			flash[:notice] = l(:notice_successful_update)
	   else
			flash[:error] = errorMsg
			redirect_to :action => 'edit', :payment_id => @payment.id
	   end
	end
  
	def getBillableProjIds
		projArr = ""	
		billProjId = getProjArrays(params[:related_to], params[:related_parent])
		if !billProjId.blank?
			billProjId.each do | entry|
				projArr <<  entry.project_id.to_s() + ',' + entry.project_name.to_s()  + "\n" 
			end
		end
		respond_to do |format|
			format.text  { render :text => projArr }
		end
		
	end
	
	# Move to Billing Helper 
	# def getProjArrays( parentType, parentId)		
		# sqlStr = "left outer join projects on projects.id = wk_account_projects.project_id "
		# if !parentId.blank?
				# sqlStr = sqlStr + " where wk_account_projects.parent_id = #{parentId} and wk_account_projects.parent_type = '#{parentType}' "
		# end
		
		# WkAccountProject.joins(sqlStr).select("projects.name as project_name, projects.id as project_id").distinct(:project_id)
	# end
  
    def set_filter_session
        if params[:searchlist].blank? && session[:payment].nil?
			session[:payment] = {:period_type => params[:period_type],:period => params[:period], :contact_id => params[:contact_id], :account_id => params[:account_id], :polymorphic_filter =>  params[:polymorphic_filter], :from => @from, :to => @to }
		elsif params[:searchlist] =='payment'
			session[:payment][:period_type] = params[:period_type]
			session[:payment][:period] = params[:period]
			session[:payment][:from] = params[:from]
			session[:payment][:to] = params[:to]
			session[:payment][:contact_id] = params[:contact_id]
			session[:payment][:account_id] = params[:account_id]
			session[:payment][:polymorphic_filter] = params[:polymorphic_filter]
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
		@payment_entries = entries.limit(@limit).offset(@offset)
	end
	
	# Retrieves the date range based on predefined ranges or specific from/to param dates
	def retrieve_date_range
		@free_period = false
		@from, @to = nil, nil
		period_type = session[:payment][:period_type]
		period = session[:payment][:period]
		fromdate = session[:payment][:from]
		todate = session[:payment][:to]
		
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

end
