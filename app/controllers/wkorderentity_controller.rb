class WkorderentityController < WkbillingController
  unloadable

before_filter :require_login

include WktimeHelper
include WkinvoiceHelper
include WkbillingHelper
include WkorderentityHelper

	def index
		@projects = nil
		errorMsg = nil
		@previewBilling = false
		set_filter_session
		retrieve_date_range
		sqlwhere = ""
	#	accountId = session[:wkinvoice][:account_id]
	#	projectId	= session[:wkinvoice][:project_id]
		filter_type = session[controller_name][:polymorphic_filter]
		contact_id = session[controller_name][:contact_id]
		account_id = session[controller_name][:account_id]
		projectId	= session[controller_name][:project_id]
		rfqId	= session[controller_name][:rfq_id]
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
		#unless (params[:generate].blank? || ) || (          !to_boolean(params[:generate]) || !to_boolean(params[:preview_billing]))
		if (!params[:preview_billing].blank? && params[:preview_billing] == "true") ||
		   (!params[:generate].blank? && params[:generate] == "true")
			if !projectId.blank? && projectId.to_i != 0
				sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
				sqlwhere = sqlwhere + " project_id = '#{projectId}' "
			end
			if filter_type == '2'  || filter_type == '3' 
				accProjects = WkAccountProject.where(sqlwhere).order(:parent_type, :parent_id)
				previewBilling(accProjects)
				accProjects.find_each do |accProj|
				   errorMsg = generateInvoices(accProj, projectId, @to + 1, [@from, @to]) unless params[:generate].blank? || !to_boolean(params[:generate])#accProj.parent_id,accProj.parent_type
				   
				end
			end			
			
			if filter_type == '1'  
				if  projectId.blank?
					accProjects = WkAccountProject.all.order(:parent_type, :parent_id)					
				else
					accProjects = WkAccountProject.where(project_id: projectId).order(:parent_type, :parent_id)
				end	
				previewBilling(accProjects)
				accProjects.each do |accProj|
				   errorMsg = generateInvoices(accProj, projectId, @to + 1, [@from, @to]) unless params[:generate].blank? || !to_boolean(params[:generate])#accProj.parent_id,accProj.parent_type
				   
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
			sqlwhere = " invoice_type = '#{getInvoiceType}'"	
			if !@from.blank? && !@to.blank?			
				sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
				sqlwhere = sqlwhere + " invoice_date between '#{@from}' and '#{@to}'  "
			end
			
			if filter_type == '1' && (projectId.blank? || projectId == 0)
				invEntries = WkInvoice.includes(:invoice_items).where(sqlwhere)
			else
				invEntries = WkInvoice.includes(:invoice_items).where(sqlwhere)
			end
			
			if !projectId.blank? && projectId.to_i != 0
				invEntries = invEntries.where( :wk_invoice_items => { :project_id => projectId })
			end	
			
			if !rfqId.blank? && rfqId.to_i != 0
				invIds = getInvoiceIds(rfqId, getInvoiceType, false)
				invEntries = invEntries.where( :id => invIds)
			end	
			formPagination(invEntries)
			@totalInvAmt = @invoiceEntries.sum("wk_invoice_items.amount") unless @previewBilling
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
		@invoice.start_date = startDate #params[:start_date]
		@invoice.end_date = endDate #params[:end_date]
		@invoice.status = 'o'
		@invoice.modifier_id = User.current.id
		@invoice.parent_id = relatedParent #params[:related_parent].to_i
		@invoice.parent_type = relatedTo #params[:related_to]		
	end
	
	def new
	
	end
	
	def update
		errorMsg = nil
		invoiceItem = nil
		#invItemId = WkInvoiceItem.select(:id).where(:invoice_id => params["invoice_id"].to_i) 
		#arrId = invItemId.map {|i| i.id }
		unless params["invoice_id"].blank?
			@invoice = WkInvoice.find(params["invoice_id"].to_i)
			@invoice.invoice_date = params[:inv_date]
			arrId = @invoice.invoice_items.pluck(:id)
		else
			@invoice = WkInvoice.new
			invoicePeriod = [params[:inv_start_date], params[:inv_end_date]]
			saveOrderInvoice(params[:parent_id], params[:parent_type],  params[:project_id1],params[:inv_date],  invoicePeriod, false, getInvoiceType)
			#addInvoice(params[:parent_id], params[:parent_type],  params[:project_id1],params[:inv_date],  invoicePeriod, false, getInvoiceType)
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
				amount = params["rate#{i}"].to_f * params["quantity#{i}"].to_f
				updatedItem = updateInvoiceItem(invoiceItem, pjtId,  params["name#{i}"], params["rate#{i}"].to_f, params["quantity#{i}"].to_f, invoiceItem.currency, itemType, amount, crInvoiceId, crPaymentId)
			else				
				invoiceItem = @invoice.invoice_items.new
				amount = params["rate#{i}"].to_f * params["quantity#{i}"].to_f
				updatedItem = updateInvoiceItem(invoiceItem, pjtId, params["name#{i}"], params["rate#{i}"].to_f, params["quantity#{i}"].to_f, params["currency#{i}"], itemType, amount, crInvoiceId, crPaymentId)
			end
			if !params[:populate_unbilled].blank? && params[:populate_unbilled] == "true" && params[:creditfrominvoice].blank? && !params["entry_id#{i}"].blank?
				accProject = WkAccountProject.where(:project_id => pjtId)
				if accProject[0].billing_type == 'TM'
					idArr = params["entry_id#{i}"].split(' ')
					idArr.each do | id |
						timeEntry = TimeEntry.find(id)
						updateBilledHours(timeEntry, @invoice.id)
					end
				elsif !params["entry_id#{i}"].blank?
					scheduledEntry = WkBillingSchedule.find(params["entry_id#{i}"].to_i)
					scheduledEntry.invoice_id = @invoice.id
					scheduledEntry.save()
				end
				
			end
			savedRows = savedRows + 1
			tothash[updatedItem.project_id] = [(tothash[updatedItem.project_id].blank? ? 0 : tothash[updatedItem.project_id][0]) + updatedItem.amount, updatedItem.currency]
		end
		
		if !arrId.blank?
			deleteBilledEntries(arrId)
			WkInvoiceItem.delete_all(:id => arrId)
		end
		
		parentId = @invoice.parent_id
		parentType = @invoice.parent_type
		tothash.each do|key, val|
			accountProject = WkAccountProject.where("project_id = ?  and parent_id = ? and parent_type = ? ", key, parentId, parentType) #'WkAccount')
			addTaxes(accountProject[0], val[1], val[0])
		end
		
		unless @invoice.id.blank?
			# case getInvoiceType			
			# when 'Q'
			  # saveRfqQuotes(params[:rfq_quote_id], params[:rfq_id].to_i, @invoice.id, params[:quote_won], params[:winning_note])	
			# when 'PO'
				# savePurchaseOrderQuotes(params[:po_id],  @invoice.id, params[:po_quote_id] )
			# when 'SI'
				# savePoSupInv(params[:si_id], params[:si_inv_id], @invoice.id)
			# end
			saveOrderRelations
			totalAmount = @invoice.invoice_items.sum(:amount)
			if (totalAmount.round - totalAmount) != 0
				addRoundInvItem(totalAmount)
			end
			if totalAmount > 0 && autoPostGL(getAutoPostModule) && postableInvoice
				transId = @invoice.gl_transaction.blank? ? nil : @invoice.gl_transaction.id
				glTransaction = postToGlTransaction(getAutoPostModule, transId, @invoice.invoice_date, totalAmount.round, @invoice.invoice_items[0].currency, nil, nil)
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
		#invoice.destroy
		#flash[:notice] = l(:notice_successful_delete)
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end    
	
  	def set_filter_session
        if params[:searchlist].blank? && session[controller_name].nil?
			session[controller_name] = {:period_type => params[:period_type],:period => params[:period], :contact_id => params[:contact_id], :account_id => params[:account_id], :project_id => params[:project_id], :polymorphic_filter =>  params[:polymorphic_filter], :rfq_id => params[:rfq_id], :from => @from, :to => @to}
		elsif params[:searchlist] == controller_name
			session[controller_name][:period_type] = params[:period_type]
			session[controller_name][:period] = params[:period]
			session[controller_name][:from] = params[:from]
			session[controller_name][:to] = params[:to]
			session[controller_name][:contact_id] = params[:contact_id]
			session[controller_name][:project_id] = params[:project_id]
			session[controller_name][:account_id] = params[:account_id]
			session[controller_name][:polymorphic_filter] = params[:polymorphic_filter]
			session[controller_name][:rfq_id] = params[:rfq_id]
		end
		
   end
   
	
	def formPagination(entries)
		@entry_count = entries.count
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
		Setting.plugin_redmine_wktime['wktime_company_name'] + "\n" +  Setting.plugin_redmine_wktime['wktime_company_address']
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
end
