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

class WkinvoiceController < WkbillingController
  
before_filter :require_login

include WktimeHelper
include WkinvoiceHelper
include WkbillingHelper

	def index
		@projects = nil
		errorMsg = nil
		@previewBilling = false
		set_filter_session
		retrieve_date_range
		sqlwhere = ""
	#	accountId = session[:wkinvoice][:account_id]
	#	projectId	= session[:wkinvoice][:project_id]
		filter_type = session[:wkinvoice][:polymorphic_filter]
		contact_id = session[:wkinvoice][:contact_id]
		account_id = session[:wkinvoice][:account_id]
		projectId	= session[:wkinvoice][:project_id]
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
					redirect_to :action => 'index' , :tab => 'wkinvoice'
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
			formPagination(invEntries)
			@totalInvAmt = @invoiceEntries.sum("wk_invoice_items.amount") unless @previewBilling
		end
	end
	
	def previewBilling(accountProjects)
		lastParentId = 0
		@currency = nil
		@listKey = 0
		@invList = Hash.new{|hsh,key| hsh[key] = {} }
		@previewBilling = true
		isActBilling = false
		totalInvAmt = 0
		accountProjects.each do |accProj|
			if isAccountBilling(accProj) 
				if lastParentId != accProj.parent_id
					setTempInvoice(@from, @to, accProj.parent_id, accProj.parent_type, '1', '0')
					isActBilling = true
				end
				lastParentId = accProj.parent_id
			else
				setTempInvoice(@from, @to, accProj.parent_id, accProj.parent_type, '1', accProj.project_id)
			end
			
			if  (!@invList[@listKey]['amount'].blank? && @invList[@listKey]['amount'] != 0.0) 
				totQuantity = 0
				@invItems.each do |key, value|
					totQuantity = totQuantity + value['item_quantity']
				end
				@invList[@listKey].store 'invoice_number', ""
				@invList[@listKey].store 'parent_type', accProj.parent_type
				@invList[@listKey].store 'parent_id', accProj.parent_id
				@invList[@listKey].store 'name', accProj.parent.name
				@invList[@listKey].store 'project', accProj.project.name
				@invList[@listKey].store 'project_id', accProj.project_id
				@invList[@listKey].store 'status', 'o'
				@invList[@listKey].store 'quantity', totQuantity
			#	@invList[@listKey].store 'invoice_date', Date.today
				@invList[@listKey].store 'start_date', @from
				@invList[@listKey].store 'end_date', @to
				@invList[@listKey].store 'isAccountBilling', isActBilling
				totalInvAmt = totalInvAmt + @invList[@listKey]['amount']
			#	@invList[@listKey].store 'modified_by', User.current
				@listKey = @listKey + 1
			end
		end	
		@entry_count = @invList.size
		setLimitAndOffset()
		invTotal = 0
		totlist = @invList.first(@limit*@entry_pages.page).last(@limit)
		totlist.each do |key, value|
			unless value.empty?
				invTotal = invTotal + value['amount'].to_i unless value['amount'].blank?
			end
		end
		@totalInvAmt = invTotal #totalInvAmt
	end
	
	
	def edit
		@invoice = nil
		@invoiceItem = nil
		@projectsDD = nil
        @currency = nil	
		@preBilling = false
		@preBilling = to_boolean(params[:preview_billing]) unless params[:preview_billing].blank?
		@listKey = 0
		@invList = Hash.new{|hsh,key| hsh[key] = {} }		
		if !params[:new_invoice].blank? && params[:new_invoice] == "true"
			if !params[:project_id].blank? && params[:project_id] != '0'
				@projectsDD = Project.where(:id => params[:project_id].to_i).pluck(:name, :id)				
				setTempInvoice(params[:start_date], params[:end_date], params[:related_parent], params[:related_to], params[:populate_items], params[:project_id])			
			elsif (!params[:project_id].blank? && params[:project_id] == '0') || params[:isAccBilling] == "true"
				accountProjects = WkAccountProject.where(:parent_type => params[:related_to], :parent_id => params[:related_parent].to_i)	
				unless accountProjects.blank?
					@projectsDD = accountProjects[0].parent.projects.pluck(:name, :id)
					setTempInvoice(params[:start_date], params[:end_date], params[:related_parent], params[:related_to], params[:populate_items], params[:project_id])
				else
					flash[:error] = "No projects in name."
					redirect_to :action => 'new'
				end
			else
				flash[:error] = "Please select the projects"
				redirect_to :action => 'new'
			end
			
		end
		unless params[:invoice_id].blank?
			@invoice = WkInvoice.find(params[:invoice_id].to_i)
			@invoiceItem = @invoice.invoice_items 
			@projectsDD = @invoiceItem.select(:project_id).distinct.collect{|m| [ m.project.name, m.project_id ] } 
		end
		unless params[:is_report].blank? || !to_boolean(params[:is_report])
			@invoiceItem = @invoiceItem.order(:project_id, :item_type)
			render :action => 'invreport', :layout => false
		end
		
	end
	
	def setTempInvoice(startDate, endDate, relatedParent, relatedTo, populatedItems, projectId)
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
		getTaxItems(startDate, endDate, relatedParent, relatedTo, populatedItems, projectId)
	end
	
	def getTaxItems(startDate, endDate, relatedParent, relatedTo, populatedItems, projectId)
			accPrtId = nil			
			@unbilled = false
			grandTotal = 0
			taxGrandTotal = 0
			#if !params[:project_id].blank? && params[:project_id] == '0'
			if !projectId.blank? && projectId == '0'
				accPrtId = WkAccountProject.where(:parent_type => relatedTo, :parent_id => relatedParent.to_i) #, :project_id => params[:project_id].to_i
			else
				accPrtId = WkAccountProject.where(:parent_type => relatedTo, :parent_id => relatedParent.to_i, :project_id => projectId.to_i)
			end
			calInvPaidAmount(relatedTo, relatedParent, projectId, nil, false)
			@taxVal = Hash.new{|hsh,key| hsh[key] = {} }
			indexKey = 0
			totAmount = 0.00
			accPrtId.each do | apEntry|
				#if !params[:populate_items].blank? && params[:populate_items] == '1'
				if !populatedItems.blank? && populatedItems == '1'
					@unbilled = true
					if apEntry.billing_type == 'TM'
						totAmount = saveTAMInvoiceItem(apEntry, true)
					else
						totAmount = getFcItems(apEntry, startDate, endDate)
					end
				else
					setInvItemCurrency(apEntry)
				end
				grandTotal =  grandTotal + (totAmount.blank? ? 0.00 : totAmount)
				
				aptaxes = apEntry.taxes
				aptaxes.each do | taxEntry|	
					taxAmt =  (taxEntry.rate_pct/100) * (totAmount.blank? ? 0.00 : totAmount)
					@taxVal[indexKey].store 'project_name', apEntry.project.name
					@taxVal[indexKey].store 'name', taxEntry.name
					@taxVal[indexKey].store 'rate', taxEntry.rate_pct
					@taxVal[indexKey].store 'project_id', apEntry.project_id
					@taxVal[indexKey].store 'currency', @currency
					@taxVal[indexKey].store 'amount', taxAmt
					taxGrandTotal = taxGrandTotal + taxAmt
					indexKey = indexKey + 1
				end
				totAmount = 0.00
			end	
			unless (taxGrandTotal + grandTotal) == 0.0
				@invList[@listKey].store 'amount', taxGrandTotal + grandTotal 
			end
	end
	
	def getFcItems(accountProject, startDate, endDate)
		#hashKey = 0
		totalAmt = 0		
		scheduledEntries = accountProject.wk_billing_schedules.where(:account_project_id => accountProject.id, :bill_date => startDate .. endDate, :invoice_id => nil)
		scheduledEntries.each do |entry|
			itemDesc = ""		
			if isAccountBilling(entry.account_project) #scheduledEntry.account_project.parent.account_billing
				itemDesc = entry.account_project.project.name + " - " + entry.milestone
			else
				itemDesc = entry.milestone
			end
			@invItems[@itemCount].store 'milestone_id', entry.id
			@invItems[@itemCount].store 'project_id', entry.account_project.project_id
			@invItems[@itemCount].store 'item_desc', itemDesc
			@invItems[@itemCount].store 'item_type', 'i'
			@invItems[@itemCount].store 'rate', entry.amount
			@invItems[@itemCount].store 'item_quantity', 1
			@invItems[@itemCount].store 'item_amount', entry.amount.round(2)
			@itemCount = @itemCount + 1
			totalAmt = (totalAmt + entry.amount).round(2)
		end
		totalAmt
	end
	
	def setInvItemCurrency(accProjectEntry)		
		if accProjectEntry.billing_type == 'TM'
			getRate = getProjectRateHash(accProjectEntry.project.custom_field_values)
			if getRate.blank? || getRate['rate'].blank? || getRate['rate'] <= 0
				rateHash = getIssueRateHash(accProjectEntry.project.issues.first.custom_field_values)
				@currency = rateHash['currency']
				if rateHash.blank? || rateHash['rate'].blank? || rateHash['rate'] <= 0
					userRateHash = getUserRateHash(accProjectEntry.project.users.first.custom_field_values)
					@currency = userRateHash['currency']
				end
			
			else
				@currency = getRate['currency']
			end
		else
			@currency = accProjectEntry.wk_billing_schedules[0].currency
		end
	end
	
	def new
	
	end
	
	def invreport
		@invoice = WkInvoice.find(params[:invoice_id].to_i)
		@invoiceItem = @invoice.invoice_items 
		render :action => 'invreport', :layout => false
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
			addInvoice(params[:parent_id], params[:parent_type],  params[:project_id1],params[:inv_date],  invoicePeriod, false)
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
			if params["item_id#{i}"].blank? && params["project_id#{i}"].blank?
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
			
			unless params["item_id#{i}"].blank?			
				arrId.delete(params["item_id#{i}"].to_i)
				invoiceItem = WkInvoiceItem.find(params["item_id#{i}"].to_i)
				amount = params["rate#{i}"].to_f * params["quantity#{i}"].to_f
				updatedItem = updateInvoiceItem(invoiceItem, params["project_id#{i}"],  params["name#{i}"], params["rate#{i}"].to_f, params["quantity#{i}"].to_f, invoiceItem.currency, params["item_type#{i}"], amount, crInvoiceId, crPaymentId)
			else				
				invoiceItem = @invoice.invoice_items.new
				amount = params["rate#{i}"].to_f * params["quantity#{i}"].to_f
				updatedItem = updateInvoiceItem(invoiceItem, params["project_id#{i}"], params["name#{i}"], params["rate#{i}"].to_f, params["quantity#{i}"].to_f, params["currency#{i}"], params["item_type#{i}"], amount, crInvoiceId, crPaymentId)
			end
			if !params[:populate_unbilled].blank? && params[:populate_unbilled] == "true" && params[:creditfrominvoice].blank?
				accProject = WkAccountProject.where(:project_id => params["project_id#{i}"].to_i)
				if accProject[0].billing_type == 'TM'
					idArr = params["entry_id#{i}"].split(' ')
					idArr.each do | id |
						timeEntry = TimeEntry.find(id)
						updateBilledHours(timeEntry, @invoice.id)
					end
				else
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
			totalAmount = @invoice.invoice_items.sum(:amount)
			if (totalAmount.round - totalAmount) != 0
				addRoundInvItem(totalAmount)
			end
			if totalAmount > 0 && autoPostGL
				transId = @invoice.gl_transaction.blank? ? nil : @invoice.gl_transaction.id
				glTransaction = postToGlTransaction('invoice', transId, @invoice.invoice_date, totalAmount.round, @invoice.invoice_items[0].currency)
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
	
	def deleteBilledEntries(invItemIdsArr)
		CustomField.find(getSettingCfId('wktime_billing_id_cf')).custom_values.where(:value => invItemIdsArr).delete_all unless getSettingCfId('wktime_billing_id_cf').blank? || getSettingCfId('wktime_billing_id_cf') == 0
	end
  
    def getAccountProjIds
		accArr = ""	
		accProjId = getProjArrays(params[:parent_id], params[:parent_type] )
		accPjt = WkAccountProject.where(:parent_id => params[:parent_id],:parent_type => params[:parent_type])
		unless accPjt.blank?
			if isAccountBilling(accPjt[0])
				accArr << "0" + ',' + " " + "\n" 
			end
		end
		
		if !accProjId.blank?			
			accProjId.each do | entry|
				accArr <<  entry.project_id.to_s() + ',' + entry.project_name.to_s()  + "\n" 
			end
		end
		respond_to do |format|
			format.text  { render :text => accArr }
		end
		
    end
	
  	def set_filter_session
        if params[:searchlist].blank? && session[:wkinvoice].nil?
			session[:wkinvoice] = {:period_type => params[:period_type],:period => params[:period], :contact_id => params[:contact_id], :account_id => params[:account_id], :project_id => params[:project_id], :polymorphic_filter =>  params[:polymorphic_filter], :from => @from, :to => @to}
		elsif params[:searchlist] =='wkinvoice'
			session[:wkinvoice][:period_type] = params[:period_type]
			session[:wkinvoice][:period] = params[:period]
			session[:wkinvoice][:from] = params[:from]
			session[:wkinvoice][:to] = params[:to]
			session[:wkinvoice][:contact_id] = params[:contact_id]
			session[:wkinvoice][:project_id] = params[:project_id]
			session[:wkinvoice][:account_id] = params[:account_id]
			session[:wkinvoice][:polymorphic_filter] = params[:polymorphic_filter]
		end
		
   end
   
   # Retrieves the date range based on predefined ranges or specific from/to param dates
	def retrieve_date_range
		@free_period = false
		@from, @to = nil, nil
		period_type = session[:wkinvoice][:period_type]
		period = session[:wkinvoice][:period]
		fromdate = session[:wkinvoice][:from]
		todate = session[:wkinvoice][:to]
		
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

end