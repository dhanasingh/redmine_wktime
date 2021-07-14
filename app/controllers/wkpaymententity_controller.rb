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

class WkpaymententityController < WkbillingController
  unloadable
	include WkpaymentHelper
	include WkbillingHelper
	include WktimeHelper
	include WkpaymententityHelper

  def index
		sort_init 'id', 'desc'
		sort_update 'id' => "p.id",
		'payment_date' => "p.payment_date",
		'type' => "p.parent_type",
		'name' => "CASE WHEN p.parent_type = 'WkAccount' THEN a.name ELSE CONCAT(c.first_name, c.last_name) END",
		'payment_type' => "p.payment_type_id",
		'original_amount' => "payment_original_amount",
		'amount' => "payment_amount"

		@payment_entries = nil
		sqlwhere = ""
		set_filter_session
		retrieve_date_range
		filter_type = session[controller_name].try(:[], :polymorphic_filter)
		contact_id = session[controller_name].try(:[], :contact_id)
		account_id = session[controller_name].try(:[], :account_id)

		selectStr = "select p.*, pmi.payment_amount, pmi.payment_original_amount, CASE WHEN p.parent_type = 'WkAccount' THEN a.name" +
		" ELSE #{concatColumnsSql(['c.first_name', 'c.last_name'], nil, ' ')} END as name," +
		" (#{getPersonTypeSql}) as entity_type"

		sqlStr =
			" from wk_payments p left join (select sum(original_amount) as payment_original_amount, sum(amount) as payment_amount," +
			" payment_id from wk_payment_items where is_deleted = #{booleanFormat(false)} group by payment_id) pmi" +
			" on(pmi.payment_id = p.id)" +
			" left join wk_accounts a on (p.parent_type = 'WkAccount' and p.parent_id = a.id)" +
			" left join wk_crm_contacts c on (p.parent_type = 'WkCrmContact' and p.parent_id = c.id)" +
			" where pmi.payment_amount > 0 and pmi.payment_original_amount > 0"
		sqlHook = call_hook :payment_additional_where_query if getInvoiceType == 'I'
		if filter_type == '2' && !contact_id.blank?
			sqlwhere = sqlwhere + " and p.parent_id = '#{contact_id}'  and p.parent_type = 'WkCrmContact' and ((#{getPersonTypeSql}) = '#{getOrderContactType}' " + (sqlHook.blank? ? " )" : sqlHook[0] + ")" )
		elsif filter_type == '2' && contact_id.blank?
			sqlwhere = sqlwhere + " and p.parent_type = 'WkCrmContact' and ((#{getPersonTypeSql}) = '#{getOrderContactType}'  " + (sqlHook.blank? ? " )" : sqlHook[0] + ")" )
		end

		if filter_type == '3' && !account_id.blank?
			sqlwhere = sqlwhere + " and p.parent_id = '#{account_id}'  and p.parent_type = 'WkAccount' and ((#{getPersonTypeSql}) = '#{getOrderAccountType}' " + (sqlHook.blank? ? " )" : sqlHook[0] + ")" )
		elsif filter_type == '3' && account_id.blank?
			sqlwhere = sqlwhere + " and p.parent_type = 'WkAccount' and ((#{getPersonTypeSql}) = '#{getOrderAccountType}' " + (sqlHook.blank? ? " )" : sqlHook[0] + ")" )
		end

		if !@from.blank? && !@to.blank?
			sqlwhere = sqlwhere + " and p.payment_date between '#{@from}' and '#{@to}'  "
		end

		if filter_type == '1' || filter_type.blank?
			sqlwhere = sqlwhere + " and ((#{getPersonTypeSql}) = '#{getOrderAccountType}' OR  (#{getPersonTypeSql}) = '#{getOrderContactType}' " + (sqlHook.blank? ? " )" : sqlHook[0] + ")" )
		end

		sqlStr = sqlStr + sqlwhere unless sqlwhere.blank?
		orderStr = " ORDER BY " + (sort_clause.present? ? sort_clause.first : " p.id desc")
		respond_to do |format|
			format.html do
				findBySql(selectStr, sqlStr, orderStr)
			  render :layout => !request.xhr?
			end
			format.api do
				@payment_entries = WkPayment.find_by_sql(selectStr + query + orderStr)
			end
			format.csv do
				entries = WkPayment.find_by_sql(selectStr + sqlStr + orderStr)
				headers = { payment: l(:label_txn_payment), type: l(:field_type), name: l(:field_name), payment_date: l(:label_payment_date), payment_type: l(:label_payment_type), original_amount: l(:field_original_amount), amount: l(:field_amount) }
				data = entries.map do |e|
					payment_items = e&.payment_items&.first
					{ payment: e.id, type: personTypeLabelHash[e.entity_type], name: e.name,  payment_date: e.payment_date.strftime("%Y-%m-%d"), payment_type: getPayTypeHash[e.payment_type_id], original_amount: (payment_items&.original_currency || '')+" "+e.payment_original_amount.round(2).to_s, amount: (payment_items&.currency || '')+" "+e.payment_amount.round(2).to_s }
				end
				respond_to do |format|
					format.csv {
						send_data(csv_export({headers: headers, data: data}), type: 'text/csv; header=present', filename: 'payment.csv')
					}
				end
			end
		end
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
				@paymentItem = @payment.payment_items.current_items
				unless params[:is_report].blank? || !to_boolean(params[:is_report])
					@paymentItem = @paymentItem.order(:project_id, :item_type)
				end
			end
		end
		respond_to do |format|
				format.html {
					render :layout => !request.xhr?
				}
				format.api
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

	def destroy
		payment = WkPayment.find(params[:id])
		payment.destroy
		flash[:notice] = l(:notice_successful_delete)
		redirect_back_or_default action: 'index', tab: params[:tab]
	end

	def set_filter_session
		filters = [:period_type, :period, :from, :to, :contact_id, :account_id, :polymorphic_filter]
		super(filters, {:from => @from, :to => @to})
  end

  def findBySql(selectStr, query, orderStr)
		@entry_count = findCountBySql(query, WkPayment)
		setLimitAndOffset()
		rangeStr = formPaginationCondition()
		@payment_entries = WkPayment.find_by_sql(selectStr + query + orderStr + rangeStr)
		@totalPayAmt = findSumBySql(query, 'payment_amount', WkPayment)
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

	def getBillableProjIds
		projArr = ""
		billProjId = getProjArrays(params[:related_to], params[:related_parent])
		if !billProjId.blank?
			billProjId.each do | entry|
				projArr <<  entry.project_id.to_s() + ',' + entry.project_name.to_s()  + "\n"
			end
		end
		respond_to do |format|
			format.text  { render :plain => projArr }
		end

	end

	def update
		if api_request?
			params['payment_entries'].each_with_index do |entry, index|
				entry.each do | item |
					params[item.first + (index+1).to_s] = item.last
				end
			end
			params['totalrow'] = params['payment_entries'].length
		end
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
			# After Rails 5 when assigning all model object attributes into a new object it returns id attribute value also.
				paymentItem.id = nil
				paymentItem.created_at = nil
				paymentItem.updated_at = nil
				paymentItem = nil if params["amount#{i}"].to_f == 0
			elsif params["amount#{i}"].to_f > 0
					paymentItem = @payment.payment_items.new
			end
			unless paymentItem.blank?
				unless @payment.id.blank?
					updatedItem = updatePaymentItem(paymentItem, @payment.id, params["invoice_id#{i}"], payAmount, params["invoice_org_currency#{i}"])
				end
			end
		end

		unless @payment.id.blank?
			#for mail notification
			WkPayment.send_notification(@payment)

			totalAmount = @payment.payment_items.current_items.sum(:original_amount)
			moduleAmtHash = {getAutoPostModule => [totalAmount.round, totalAmount.round]}

			transAmountArr = getTransAmountArr(moduleAmtHash, nil)
			if totalAmount > 0 && isChecked(getAuotPostId)
				transId = @payment.gl_transaction.blank? ? nil : @payment.gl_transaction.id
				glTransaction = postToGlTransaction(getAutoPostModule, transId, @payment.payment_date, transAmountArr, @payment.payment_items[0].original_currency, @payment.description, nil )
				unless glTransaction.blank?
					@payment.gl_transaction_id = glTransaction.id
					@payment.save
				end
			end
		end

		respond_to do |format|
			format.html {
					if errorMsg.nil?
							redirect_to :action => 'index' , :tab => controller_name
							flash[:notice] = l(:notice_successful_update)
					else
							flash[:error] = errorMsg
							redirect_to :action => 'edit', :payment_id => @payment.id
					end
			}
			format.api{
					if errorMsg.nil?
							render :plain => errorMsg, :layout => nil
					else
							@error_messages = errorMsg.split('\n')
							render :template => 'common/error_messages.api', :status => :unprocessable_entity, :layout => nil
					end
			}
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
