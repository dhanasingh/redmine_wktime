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
		sqlwhere = "invoice_type = '#{getInvoiceType}'"
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
			arrId = @invoice.invoice_items.pluck(:id)
		else
			@invoice = WkInvoice.new
			invoicePeriod = [params[:inv_start_date], params[:inv_end_date]]
			addInvoice(params[:parent_id], params[:parent_type],  params[:project_id1],params[:inv_date],  invoicePeriod, false, getInvoiceType)
		end
		@invoice.status = params[:field_status]
		if @invoice.status_changed?
			@invoice.closed_on = Time.now			
			@invoice.save()
		end
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
			
			unless params["item_id#{i}"].blank?			
				arrId.delete(params["item_id#{i}"].to_i)
				invoiceItem = WkInvoiceItem.find(params["item_id#{i}"].to_i)
				amount = params["rate#{i}"].to_f * params["quantity#{i}"].to_f
				updatedItem = updateInvoiceItem(invoiceItem, pjtId,  params["name#{i}"], params["rate#{i}"].to_f, params["quantity#{i}"].to_f, invoiceItem.currency, params["item_type#{i}"], amount, crInvoiceId, crPaymentId)
			else				
				invoiceItem = @invoice.invoice_items.new
				amount = params["rate#{i}"].to_f * params["quantity#{i}"].to_f
				updatedItem = updateInvoiceItem(invoiceItem, pjtId, params["name#{i}"], params["rate#{i}"].to_f, params["quantity#{i}"].to_f, params["currency#{i}"], params["item_type#{i}"], amount, crInvoiceId, crPaymentId)
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
			case getInvoiceType			
			when 'Q'
			  saveRfqQuotes(params[:rfq_quote_id], params[:rfq_id].to_i, @invoice.id, params[:quote_won], params[:winning_note])	
			when 'PO'
				savePurchaseOrderQuotes(params[:po_id],  @invoice.id, params[:po_quote_id] )
			when 'SI'
				savePoSupInv(params[:si_id], params[:si_inv_id], @invoice.id)
			end
			totalAmount = @invoice.invoice_items.sum(:amount)
			if (totalAmount.round - totalAmount) != 0
				addRoundInvItem(totalAmount)
			end
			if totalAmount > 0 && autoPostGL
				transId = @invoice.gl_transaction.blank? ? nil : @invoice.gl_transaction.id
				glTransaction = postToGlTransaction('invoice', transId, @invoice.invoice_date, totalAmount.round, @invoice.invoice_items[0].currency, nil)
				unless glTransaction.blank?
					@invoice.gl_transaction_id = glTransaction.id
					@invoice.save
				end				
			end
		end
		
		if errorMsg.nil? 
			redirect_to :action => 'index' , :tab => 'wkinvoice'
			flash[:notice] = l(:notice_successful_update)
	   else
			flash[:error] = errorMsg
			redirect_to :action => 'edit', :invoice_id => @invoice.id
	   end
	end
	
	def destroy
		invoice = WkInvoice.find(params[:invoice_id].to_i)#.destroy
		deleteBilledEntries(invoice.invoice_items.pluck(:id))
		invoice.destroy
		flash[:notice] = l(:notice_successful_delete)
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
   
   # Retrieves the date range based on predefined ranges or specific from/to param dates
	def retrieve_date_range
		@free_period = false
		@from, @to = nil, nil
		period_type = session[controller_name][:period_type]
		period = session[controller_name][:period]
		fromdate = session[controller_name][:from]
		todate = session[controller_name][:to]
		
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
	
	def getRfqQuoteIds
		quoteIds = ""	
		rfqObj = ""
		if params[:inv_type] == 'PO'		
			rfqObj = WkInvoice.where(:id => getInvoiceIds(params[:rfq_id].to_i, 'Q', true), :parent_id => params[:parent_id].to_i, :parent_type => params[:parent_type]).order(:id)
		elsif params[:inv_type] == 'SI'
			rfqObj = WkInvoice.where(:id => getInvoiceIds(params[:rfq_id].to_i, 'PO', false), :parent_id => params[:parent_id].to_i, :parent_type => params[:parent_type]).order(:id)
		end
		rfqObj.each do | entry|
			quoteIds <<  entry.id.to_s() + ',' + entry.id.to_s()  + "\n" 
		end
		respond_to do |format|
			format.text  { render :text => quoteIds }
		end
	end
	
	def getLabelInvNum
		l(:label_invoice_number)
	end
	
	def getLabelNewInv
		l(:label_new_invoice)
	end
	
	def getHeaderLabel
		l(:label_invoice)
	end
	
	def getItemLabel
		l(:label_invoice_items)
	end
	
	def getDateLbl
		l(:label_invoice_date)
	end	
	
end
