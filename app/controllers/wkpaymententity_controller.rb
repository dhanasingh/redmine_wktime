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

class WkpaymententityController < WkbillingController
  unloadable
	include WkpaymentHelper
    include WkbillingHelper
    include WktimeHelper
	include WkpaymententityHelper
	
    def index
		@payment_entries = nil
		sqlwhere = ""
		set_filter_session
		retrieve_date_range
		filter_type = session[controller_name][:polymorphic_filter]
		contact_id = session[controller_name][:contact_id]
		account_id = session[controller_name][:account_id]
		
		sqlStr = "select p.*, pmi.payment_amount, CASE WHEN p.parent_type = 'WkAccount' THEN a.name" +
			" ELSE #{concatColumnsSql(['c.first_name', 'c.last_name'], nil, ' ')} END as name," +
			" (#{getPersonTypeSql}) as entity_type" + 
			" from wk_payments p left join (select sum(amount) as payment_amount," +
			" payment_id from wk_payment_items where is_deleted = #{false} group by payment_id) pmi" +
			" on(pmi.payment_id = p.id)" +
			" left join wk_accounts a on (p.parent_type = 'WkAccount' and p.parent_id = a.id)" +
			" left join wk_crm_contacts c on (p.parent_type = 'WkCrmContact' and p.parent_id = c.id)" +
			" where pmi.payment_amount > 0 " 
		if filter_type == '2' && !contact_id.blank?
			# sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " and p.parent_id = '#{contact_id}'  and p.parent_type = 'WkCrmContact' and (#{getPersonTypeSql}) = '#{getOrderContactType}' "
		elsif filter_type == '2' && contact_id.blank?
			#sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " and p.parent_type = 'WkCrmContact' and (#{getPersonTypeSql}) = '#{getOrderContactType}'  "
		end
		
		if filter_type == '3' && !account_id.blank?
			#sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " and p.parent_id = '#{account_id}'  and p.parent_type = 'WkAccount' and (#{getPersonTypeSql}) = '#{getOrderAccountType}' "
		elsif filter_type == '3' && account_id.blank?
			#sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " and p.parent_type = 'WkAccount' and (#{getPersonTypeSql}) = '#{getOrderAccountType}' "
		end
		
		if !@from.blank? && !@to.blank?			
			#sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " and p.payment_date between '#{@from}' and '#{@to}'  "
		end
		#sqlwhere = sqlwhere + "wk_accounts.account_type = 'S' "
		
		if filter_type == '1' || filter_type.blank?
			#sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " and ((#{getPersonTypeSql}) = '#{getOrderAccountType}' OR  (#{getPersonTypeSql}) = '#{getOrderContactType}') "
		end	
		
		
		sqlStr = sqlStr + sqlwhere unless sqlwhere.blank?
		sqlStr = sqlStr + " order by p.id desc"
		findBySql(sqlStr)		
		#@totalPayAmt = @payment_entries.where("wk_payment_items.is_deleted = #{false} ").sum("wk_payment_items.amount")
    end
	
	def edit
		@payment = nil
		@accInvoices = nil
		if !params[:load_payment].blank? && params[:load_payment]
			parentType = params[:related_to]
			parentId = params[:related_parent]
			projectId = params[:project_id]
			if !parentType.blank? && !parentId.blank?
				@accInvoices = WkInvoice.where(:parent_type=> parentType, :parent_id=>parentId, :invoice_type => getInvoiceType)
			end	
		else	
			unless params[:payment_id].blank?
				@payment = WkPayment.find(params[:payment_id].to_i)
				@payemntItem = @payment.payment_items.current_items 
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

	def set_filter_session
        if params[:searchlist].blank? && session[controller_name].nil?
			session[controller_name] = {:period_type => params[:period_type],:period => params[:period], :contact_id => params[:contact_id], :account_id => params[:account_id], :polymorphic_filter =>  params[:polymorphic_filter], :from => @from, :to => @to }
		elsif params[:searchlist] == controller_name
			session[controller_name][:period_type] = params[:period_type]
			session[controller_name][:period] = params[:period]
			session[controller_name][:from] = params[:from]
			session[controller_name][:to] = params[:to]
			session[controller_name][:contact_id] = params[:contact_id]
			session[controller_name][:account_id] = params[:account_id]
			session[controller_name][:polymorphic_filter] = params[:polymorphic_filter]
		end
		
    end
	
    def findBySql(query)
		result = WkPayment.find_by_sql("select count(*) as id from (" + query + ") as v2")
	    @entry_count = result.blank? ? 0 : result[0].id
	    setLimitAndOffset()		
	    rangeStr = formPaginationCondition()	
	    @payment_entries = WkPayment.find_by_sql(query + rangeStr)
		result = WkPayment.find_by_sql("select sum(v2.payment_amount) as payment_amount from (" + query + ") as v2")
		@totalPayAmt = result.blank? ? 0 : result[0].payment_amount
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
	
	def formPaginationCondition
		rangeStr = ""
		if ActiveRecord::Base.connection.adapter_name == 'SQLServer'				
			rangeStr = " OFFSET " + @offset.to_s + " ROWS FETCH NEXT " + @limit.to_s + " ROWS ONLY "
		else		
			rangeStr = " LIMIT " + @limit.to_s +	" OFFSET " + @offset.to_s
		end
		rangeStr
	end
	
	# def setLimitAndOffset		
		# if api_request?
			# @offset, @limit = api_offset_and_limit
			# if !params[:limit].blank?
				# @limit = params[:limit]
			# end
			# if !params[:offset].blank?
				# @offset = params[:offset]
			# end
		# else
			# @entry_pages = Paginator.new @entry_count, per_page_option, params['page']
			# @limit = @entry_pages.per_page
			# @offset = @entry_pages.offset
		# end	
	# end
	
	
    # def formPagination(entries)
		# @entry_count = entries.count
        # setLimitAndOffset()
		# @payment_entries = entries.order(id: :desc).limit(@limit).offset(@offset)
	# end
	
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
		if totalRow>0 && params["tot_pay_amount"].to_i > 0
			@payment.save()
		end
		for i in 1..totalRow
			if params["credit_issued#{i}"] == "true"
				payAmount = params["paid_amount#{i}"].to_f
			else
				payAmount = params["amount#{i}"].to_f
			end
			paymentItem = nil
			if !params["payment_item_id#{i}"].blank?	
				oldpaymentItem = WkPaymentItem.find(params["payment_item_id#{i}"].to_i)
				oldpaymentItem.is_deleted = true
				oldpaymentItem.save()
				paymentItem = WkPaymentItem.new(oldpaymentItem.attributes)
				paymentItem.created_at = nil
				paymentItem.updated_at = nil
				paymentItem = nil if params["amount#{i}"].to_f == 0
			elsif params["amount#{i}"].to_f > 0
					paymentItem = @payment.payment_items.new
			end
			unless paymentItem.blank?
				unless @payment.id.blank?
					# glTransactionId = nil
					# if isChecked('invoice_auto_post_gl')
						# transId = paymentItem.gl_transaction.blank? ? nil : paymentItem.gl_transaction.id
						# glTransaction = postToGlTransaction('payment', transId, @payment.payment_date, payAmount, params["currency#{i}"], params["invoice_id#{i}"])
						# glTransactionId = glTransaction.id unless glTransaction.blank?
					# end				
					updatedItem = updatePaymentItem(paymentItem, @payment.id, params["invoice_id#{i}"], payAmount, params["currency#{i}"] ) # ,glTransactionId
				end	
			end	
		end
		
		unless @payment.id.blank?
			totalAmount = @payment.payment_items.current_items.sum(:amount)
			if totalAmount > 0 && isChecked(getAuotPostId)
				transId = @payment.gl_transaction.blank? ? nil : @payment.gl_transaction.id
				glTransaction = postToGlTransaction(getAutoPostModule, transId, @payment.payment_date, totalAmount, @payment.payment_items[0].currency, @payment.description, nil )
				unless glTransaction.blank?
					@payment.gl_transaction_id = glTransaction.id
					@payment.save
				end				
			end
		end
		
		if errorMsg.nil? 
			redirect_to :action => 'index' , :tab => controller_name
			flash[:notice] = l(:notice_successful_update)
	   else
			flash[:error] = errorMsg
			redirect_to :action => 'edit', :payment_id => @payment.id
	   end
	end

	def getItemLabel
		l(:label_invoice_items)
	end
	
	def getEditHeaderLabel
		l(:label_txn_payment)
	end
	
	def getPersonTypeSql
		 "CASE WHEN p.parent_type = 'WkAccount'  THEN a.account_type ELSE c.contact_type END"
	end	
	
	def getAuotPostId
		'invoice_auto_post_gl'
	end
	
	def getAutoPostModule
		'payment'
	end
	
end
