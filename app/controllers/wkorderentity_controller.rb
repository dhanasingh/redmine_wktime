class WkorderentityController < WkbillingController
  unloadable

before_action :require_login

include WktimeHelper
include WkinvoiceHelper
include WkbillingHelper
include WkorderentityHelper
include WkreportHelper
include WkgltransactionHelper

	def index
		sort_init 'id', 'asc'

		sort_update 'invoice_number' => "invoice_number",
					'invoice_date' => "invoice_date",
					'status' => "wk_invoices.status",
					'name' => "CASE WHEN wk_invoices.parent_type = 'WkAccount' THEN a.name ELSE CONCAT(c.first_name, c.last_name) END",
					'start_date' => "start_date",
					'end_date' => "end_date",
					'amount' => "amount",
					'original_amount' => "original_amt",
					'quantity' => "quantity",
					'modified' =>  "CONCAT(users.firstname, users.lastname)"

		@projects = nil
		errorMsg = nil
		@previewBilling = false
		set_filter_session
		retrieve_date_range
		sqlwhere = ""
		filter_type = session[controller_name].try(:[], :polymorphic_filter)
		contact_id = session[controller_name].try(:[], :contact_id)
		account_id = session[controller_name].try(:[], :account_id)
		projectId	= session[controller_name].try(:[], :project_id)
		rfqId	= session[controller_name].try(:[], :rfq_id)
		parentType = ""
		parentId = ""
		if filter_type == '2' && !contact_id.blank?
			parentType = 'WkCrmContact'
			parentId = 	contact_id
		elsif filter_type == '2' && contact_id.blank?
			parentType = 'WkCrmContact'
		end
		
		if filter_type == '3' && !account_id.blank?
			parentType =  'WkAccount'
			parentId = 	account_id
		elsif filter_type == '3' && account_id.blank?
			parentType =  'WkAccount'
		end
		
		accountProjects = getProjArrays(parentId, parentType)
		@projects = accountProjects.collect{|m| [ m.project_name, m.project_id ] } if !accountProjects.blank?
		
		unless parentId.blank? 
			sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " parent_id = '#{parentId}' "
		end
		
		unless parentType.blank?
			sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " parent_type = '#{parentType}'  "
		end
		
		if (!params[:preview_billing].blank? && params[:preview_billing] == "true") ||
		   (!params[:generate].blank? && params[:generate] == "true")
			if !projectId.blank? && projectId.to_i != 0
				sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
				sqlwhere = sqlwhere + " project_id = '#{projectId}' "
			end
			if filter_type == '2'  || filter_type == '3' 
				accProjects = WkAccountProject.where(sqlwhere).order(:parent_type, :parent_id)
				# previewBilling(accProjects)
				# accProjects.find_each do |accProj|
				   # errorMsg = generateInvoices(accProj, projectId, @to + 1, [@from, @to]) unless params[:generate].blank? || !to_boolean(params[:generate])#accProj.parent_id,accProj.parent_type
				   
				# end
			end			
			
			if filter_type == '1'  
				if  projectId.blank?
					accProjects = WkAccountProject.all.order(:parent_type, :parent_id)					
				else
					accProjects = WkAccountProject.where(project_id: projectId).order(:parent_type, :parent_id)
				end	
				# previewBilling(accProjects)
				# accProjects.each do |accProj|
				   # errorMsg = generateInvoices(accProj, projectId, @to + 1, [@from, @to]) unless params[:generate].blank? || !to_boolean(params[:generate])
				   
				# end
			end
			invoiceFreq = getInvFreqAndFreqStart
			invIntervals = getIntervals(@from, @to, invoiceFreq["frequency"], invoiceFreq["start"], true, false)
			@firstInterval = invIntervals[0]
			previewBilling(accProjects, @from, @to)
			invIntervals.each do |interval|
				accProjects.find_each do |accProj|
				   errorMsg = generateInvoices(accProj, projectId, interval[1] + 1, interval) unless params[:generate].blank? || !to_boolean(params[:generate])#accProj.parent_id,accProj.parent_type
				   
				end
			end
			unless params[:generate].blank? || !to_boolean(params[:generate])
				if errorMsg.blank?	
					redirect_to :action => 'index' , :tab => controller_name
					flash[:notice] = l(:notice_successful_update)
				else
					if errorMsg.is_a?(Hash)
						flash[:notice] = l(:notice_successful_update)
						flash[:error] = errorMsg['trans']
					else
						flash[:error] = errorMsg
					end
					redirect_to :action => 'index'
				end	
			end
		else	
			sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " invoice_type = '#{getInvoiceType}'"	
			if !@from.blank? && !@to.blank?			
				sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
				sqlwhere = sqlwhere + " invoice_date between '#{@from}' and '#{@to}'  "
			end

			invEntries = WkInvoice.where(sqlwhere)
	
			if !projectId.blank? && projectId.to_i != 0
				invEntries = invEntries.where( :wk_invoice_items => { :project_id => projectId })
			end	
			
			if !rfqId.blank? && rfqId.to_i != 0
				invIds = getInvoiceIds(rfqId, getInvoiceType, false)
				invEntries = invEntries.where( :id => invIds)
			end
			invEntries = invEntries.joins("LEFT JOIN wk_invoice_items ON wk_invoice_items.invoice_id = wk_invoices.id
				LEFT JOIN (SELECT id, firstname, lastname FROM users) AS users ON wk_invoices.modifier_id = users.id
				LEFT JOIN wk_accounts a on (wk_invoices.parent_type = 'WkAccount' and wk_invoices.parent_id = a.id)
				LEFT JOIN wk_crm_contacts c on (wk_invoices.parent_type = 'WkCrmContact' and wk_invoices.parent_id = c.id)
				").group("wk_invoices.id, CASE WHEN wk_invoices.parent_type = 'WkAccount' THEN a.name ELSE CONCAT(c.first_name, c.last_name) END,
				CONCAT(users.firstname, users.lastname)")
				.select("wk_invoices.*, SUM(wk_invoice_items.quantity) AS quantity, SUM(wk_invoice_items.amount) AS amount, SUM(wk_invoice_items.original_amount)
				 AS original_amt")
			formPagination(invEntries.reorder(sort_clause))

			unless @previewBilling
				amounts = @invoiceEntries.reorder(["wk_invoices.id ASC"]).pluck("SUM(wk_invoice_items.amount)")
				@totalInvAmt = amounts.inject(0, :+)
			end
		end
	end	
	
	def edit
		@invoice = nil
		@invoiceItem = nil
		@projectsDD = Array.new
        @currency = nil	
		@preBilling = false
		@rfgQuoteEntry = nil
		@rfqObj = nil
		@poObj = nil
		@siObj = nil
		@preBilling = to_boolean(params[:preview_billing]) unless params[:preview_billing].blank?
		@listKey = 0
		@invList = Hash.new{|hsh,key| hsh[key] = {} }	
		parentType = ""
		parentId = ""
		filter_type = params[:polymorphic_filter]
		contact_id = params[:polymorphic_filter]
		account_id = params[:polymorphic_filter]
		if filter_type == '2' && !contact_id.blank?
			parentType = 'WkCrmContact'
			parentId = 	params[:contact_id]
		elsif filter_type == '2' && contact_id.blank?
			parentType = 'WkCrmContact'
		end
		
		if filter_type == '3' && !account_id.blank?
			parentType =  'WkAccount'
			parentId = 	params[:account_id]
		elsif filter_type == '3' && account_id.blank?
			parentType =  'WkAccount'
		end
		
		if parentId.blank? && parentType.blank?
			parentType = params[:related_to]
			parentId = params[:related_parent]
		end
		
		if !params[:new_invoice].blank? && params[:new_invoice] == "true"			
			if parentId.blank?
				flash[:error] = "Account and Contacts can't be empty."
				return redirect_to :action => 'new'
			end
			newOrderEntity(parentId, parentType)
		end		
		editOrderEntity
		unless params[:is_report].blank? || !to_boolean(params[:is_report])
			@invoiceItem = @invoiceItem.order(:project_id, :item_type)
			render :action => 'invreport', :layout => false
		end
		
	end
	
	def invreport
		@invoice = WkInvoice.find(params[:invoice_id].to_i)
		@invoiceItem = @invoice.invoice_items 
		render :action => 'invreport', :layout => false
	end
	
	def newOrderEntity(parentId, parentType)	
	end	
	
	def editOrderEntity			
		unless params[:invoice_id].blank?
			@invoice = WkInvoice.find(params[:invoice_id].to_i)
			@invoiceItem = @invoice.invoice_items 
			@invPaymentItems = @invoice.payment_items.current_items				
			pjtList = @invoiceItem.select(:project_id).distinct
			pjtList.each do |entry| 
				@projectsDD << [ entry.project.name, entry.project_id ] if !entry.project_id.blank? && entry.project_id != 0  
			end			
		end		
	end
	
	def setTempEntity(startDate, endDate, relatedParent, relatedTo, populatedItems, projectId)
		@itemCount = 0
		@invItems = Hash.new{|hsh,key| hsh[key] = {} }		
		@invoice = WkInvoice.new
		@invoice.invoice_date = Date.today
		@invoice.id = ""
		@invoice.invoice_number = ""
		@invoice.start_date = startDate 
		@invoice.end_date = endDate 
		@invoice.status = 'o'
		@invoice.modifier_id = User.current.id
		@invoice.parent_id = relatedParent 
		@invoice.parent_type = relatedTo 		
	end
	
	def new
	
	end
	
	def update
		errorMsg = nil
		invoiceItem = nil
		unless params["invoice_id"].blank?
			@invoice = WkInvoice.find(params["invoice_id"].to_i)
			@invoice.invoice_date = params[:inv_date]
			arrId = @invoice.invoice_items.pluck(:id)
		else
			@invoice = WkInvoice.new
			invoicePeriod = getInvoicePeriod(params[:inv_start_date], params[:inv_end_date])#[params[:inv_start_date], params[:inv_end_date]]
			saveOrderInvoice(params[:parent_id], params[:parent_type],  params[:project_id1],params[:inv_date],  invoicePeriod, false, getInvoiceType)
			
		end
		@invoice.status = params[:field_status] unless params[:field_status].blank?
		unless params[:inv_number].blank?
			@invoice.invoice_number = params[:inv_number]
		end
		if @invoice.status_changed?
			@invoice.closed_on = Time.now			
		end
		@invoice.save()
		totalAmount = 0
		tothash = Hash.new
		totalRow = params[:totalrow].to_i
		savedRows = 0
		deletedRows = 0
		productArr = Array.new
		@matterialVal = Hash.new{|hsh,key| hsh[key] = {} }
		@totalMatterialAmount = 0.00
		#for i in 1..totalRow
		while savedRows < totalRow
			i = savedRows + deletedRows + 1
			if params["item_id#{i}"].blank? && params["quantity#{i}"].blank? #&& params["project_id#{i}"].blank?
				deletedRows = deletedRows + 1
				next
			end
			crInvoiceId = nil
			crPaymentId = nil
			if params["creditfrominvoice#{i}"] == "true"
				crInvoiceId = params["entry_id#{i}"].to_i
			elsif params["creditfrominvoice#{i}"] == "false"
				crPaymentId = params["entry_id#{i}"].to_i
			end
			pjtId = params["project_id#{i}"] if !params["project_id#{i}"].blank?
			itemType = params["item_type#{i}"].blank? ? params["hd_item_type#{i}"]  : params["item_type#{i}"]
			unless params["item_id#{i}"].blank?			
				arrId.delete(params["item_id#{i}"].to_i)
				invoiceItem = WkInvoiceItem.find(params["item_id#{i}"].to_i)
				org_amount = params["rate#{i}"].to_f * params["quantity#{i}"].to_f
				updatedItem = updateInvoiceItem(invoiceItem, pjtId,  params["name#{i}"], params["rate#{i}"].to_f, params["quantity#{i}"].to_f, invoiceItem.original_currency, itemType, org_amount, crInvoiceId, crPaymentId, params["product_id#{i}"])
			else				
				invoiceItem = @invoice.invoice_items.new
				org_amount = params["rate#{i}"].to_f * params["quantity#{i}"].to_f
				updatedItem = updateInvoiceItem(invoiceItem, pjtId, params["name#{i}"], params["rate#{i}"].to_f, params["quantity#{i}"].to_f, params["original_currency#{i}"], itemType, org_amount, crInvoiceId, crPaymentId, params["product_id#{i}"])
			end
			if !params[:populate_unbilled].blank? && params[:populate_unbilled] == "true" && params[:creditfrominvoice].blank? && !params["entry_id#{i}"].blank?
				accProject = WkAccountProject.where(:project_id => pjtId)
				if accProject[0].billing_type == 'TM'
					idArr = params["entry_id#{i}"].split(' ')
					idArr.each do | id |
						timeEntry = TimeEntry.find(id)
						updateBilledEntry(timeEntry, updatedItem.id)
					end
				elsif !params["entry_id#{i}"].blank?
					scheduledEntry = WkBillingSchedule.find(params["entry_id#{i}"].to_i)
					scheduledEntry.invoice_id = @invoice.id
					scheduledEntry.save()
				end
				
			end
			unless params["material_id#{i}"].blank?
				matterialEntry = WkMaterialEntry.find(params["material_id#{i}"].to_i)
				updateBilledEntry(matterialEntry, updatedItem.id)
				# matterialEntry.invoice_item_id = updatedItem.id
				# matterialEntry.save
			end
			savedRows = savedRows + 1
			tothash[updatedItem.project_id] = [(tothash[updatedItem.project_id].blank? ? 0 : tothash[updatedItem.project_id][0]) + updatedItem.original_amount, updatedItem.original_currency] if updatedItem.item_type != 'm'
			
			unless params["product_id#{i}"].blank?
				productId = params["product_id#{i}"]
				productEntry = WkProduct.find(productId)
				projEntry = Project.find(pjtId)
				productName = productEntry.name
				amount = params["rate#{i}"].to_f * params["quantity#{i}"].to_f
				curr = params["currency#{i}"]
				productArr << productId 
				if @matterialVal.has_key?("#{productId}")
					oldAmount = @matterialVal["#{productId}"]["amount"].to_i
					totAmount = oldAmount + amount
					@matterialVal["#{productId}"].store "amount", "#{totAmount}"
				else
					@matterialVal["#{productId}"].store "amount", "#{amount}"
					@matterialVal["#{productId}"].store "currency", "#{curr}"
					@matterialVal["#{productId}"].store "pname", "#{productName}"
					@matterialVal["#{productId}"].store "projectId", "#{projEntry.id}"
					@matterialVal["#{productId}"].store "projectName", "#{projEntry.name}"
				end
			end	
		end
		
		if !arrId.blank?
			deleteBilledEntries(arrId)
			WkInvoiceItem.where(:id => arrId).delete_all
		end
		
		parentId = @invoice.parent_id
		parentType = @invoice.parent_type
		tothash.each do|key, val|
			accountProject = WkAccountProject.where("project_id = ?  and parent_id = ? and parent_type = ? ", key, parentId, parentType) #'WkAccount')
			addTaxes(accountProject[0], val[1], val[0])
		end
		addProductTaxes(productArr, true)
		
		unless @invoice.id.blank?
			saveOrderRelations
			totalAmount = @invoice.invoice_items.sum(:original_amount)
			invoiceAmount = @invoice.invoice_items.where.not(:item_type => 'm').sum(:original_amount)
			
			moduleAmtHash = {'inventory' => [nil, totalAmount.round - invoiceAmount.round], getAutoPostModule => [totalAmount.round, invoiceAmount.round]}
			inverseModuleArr = ['inventory']
			transAmountArr = getTransAmountArr(moduleAmtHash, inverseModuleArr)
			if (totalAmount.round - totalAmount) != 0
				addRoundInvItem(totalAmount)
			end
			if totalAmount > 0 && autoPostGL(getAutoPostModule) && postableInvoice
				transId = @invoice.gl_transaction.blank? ? nil : @invoice.gl_transaction.id
				glTransaction = postToGlTransaction(getAutoPostModule, transId, @invoice.invoice_date, transAmountArr, @invoice.invoice_items[0].original_currency, invoiceDesc(@invoice,invoiceAmount), nil)
				unless glTransaction.blank?
					@invoice.gl_transaction_id = glTransaction.id
					@invoice.save
				end				
			end
		end
		
		if errorMsg.nil? 
			redirect_to :action => 'index' , :tab => controller_name
			flash[:notice] = l(:notice_successful_update)
	   else
			flash[:error] = errorMsg
			redirect_to :action => 'edit', :invoice_id => @invoice.id
	   end
	end
	
	def getHeaderLabel
		l(:label_invoice)
	end
	
	def saveOrderInvoice(parentId, parentType,  projectId, invDate,  invoicePeriod, isgenerate, getInvoiceType)
	end
	
	def saveOrderRelations		
	end
	
	def deleteBilledEntries(invItemIdsArr)
	end
	
	def getInvoicePeriod(startDate, endDate)
		[startDate, endDate]
	end
	
	def getOrderContract(invoice)
		contractStr = nil
		accContract = invoice.parent.contract(@invoiceItem[0].project)
		unless accContract.blank?
			contractStr = accContract.contract_number + " - " + accContract.start_date.to_formatted_s(:long)
		end
		contractStr
	end
	
	def destroy
		invoice = WkInvoice.find(params[:invoice_id].to_i)#.destroy
		deleteBilledEntries(invoice.invoice_items.pluck(:id))
		if invoice.destroy
			flash[:notice] = l(:notice_successful_delete)
		else
			flash[:error] = invoice.errors.full_messages.join("<br>")
		end
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end    
	
  	def set_filter_session
			session[controller_name] = {:from => @from, :to => @to} if session[controller_name].nil?
		if params[:searchlist] == controller_name
			filters = [:period_type, :period, :from, :to, :contact_id, :account_id, :project_id, :polymorphic_filter, :rfq_id]
			filters.each do |param|
				if params[param].blank? && session[controller_name].try(:[], param).present?
					session[controller_name].delete(param)
				elsif params[param].present?
					session[controller_name][param] = params[param]
				end
			end
		end
    end
   
	
	def formPagination(entries)
		@entry_count = entries.length
        setLimitAndOffset()
		@invoiceEntries = entries.order(:id).limit(@limit).offset(@offset)
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
	
	def getOrderComponetsId
		'wktime_invoice_components'
	end
	
	def getSupplierAddress(invoice)
		getMainLocation + "\n" +  getAddress
	end
	
	def getCustomerAddress(invoice)
		invoice.parent.name + "\n" + (invoice.parent.address.blank? ? "" : invoice.parent.address.fullAddress)
	end
	
	def getAutoPostModule	
	end
	
	def postableInvoice
		false
	end
	
	def deletePermission
		false
	end
	
	def addMaterialType
		false
	end
	
	def addAssetType
		false
	end
	
	def getAccountLbl
		l(:label_account)
	end
	
	def showProjectDD
		false
	end
	
end
