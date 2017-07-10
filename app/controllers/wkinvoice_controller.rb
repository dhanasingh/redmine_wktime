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

class WkinvoiceController < WkorderentityController
	@@invmutex = Mutex.new

	def newOrderEntity(parentId, parentType)	
		newInvoice(parentId, parentType)
	end

	def newInvoice(parentId, parentType)
		if !params[:project_id].blank? && params[:project_id] != '0'
			@projectsDD = Project.where(:id => params[:project_id].to_i).pluck(:name, :id)				
			setTempEntity(params[:start_date], params[:end_date], parentId, parentType, params[:populate_items], params[:project_id])			
		elsif (!params[:project_id].blank? && params[:project_id] == '0') || params[:isAccBilling] == "true"
			accountProjects = WkAccountProject.where(:parent_type => parentType, :parent_id => parentId.to_i)	
			unless accountProjects.blank?
				@projectsDD = accountProjects[0].parent.projects.pluck(:name, :id)
				setTempEntity(params[:start_date], params[:end_date], parentId, parentType, params[:populate_items], params[:project_id])
			else
				flash[:error] = "No projects in name."
				redirect_to :action => 'new'
			end
		else
			flash[:error] = "Please select the projects"
			redirect_to :action => 'new'
		end
	end
	
	def saveOrderInvoice(parentId, parentType,  projectId, invDate,  invoicePeriod, isgenerate, getInvoiceType)
		begin			
			@@invmutex.synchronize do
				addInvoice(parentId, parentType,  projectId, invDate,  invoicePeriod, isgenerate, getInvoiceType)
			end				
		rescue => ex
		  logger.error ex.message
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
					setTempEntity(@from, @to, accProj.parent_id, accProj.parent_type, '1', '0')
					isActBilling = true
				end
				lastParentId = accProj.parent_id
			else
				isActBilling = false
				setTempEntity(@from, @to, accProj.parent_id, accProj.parent_type, '1', accProj.project_id)
			end
			
			if  (!@invList[@listKey]['amount'].blank? && @invList[@listKey]['amount'] != 0.0) 
				totQuantity = 0
				@invItems.each do |key, value|
					totQuantity = totQuantity + value['item_quantity'] unless value['item_quantity'].blank?
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
	
	def setTempEntity(startDate, endDate, relatedParent, relatedTo, populatedItems, projectId)
		super
		getInvItems(startDate, endDate, relatedParent, relatedTo, populatedItems, projectId) 
	end
	
	def getInvItems(startDate, endDate, relatedParent, relatedTo, populatedItems, projectId)
			accPrtId = nil			
			@unbilled = false
			grandTotal = 0
			taxGrandTotal = 0
			creditAmount = 0
			#if !params[:project_id].blank? && params[:project_id] == '0'
			if !projectId.blank? && projectId == '0'
				accPrtId = WkAccountProject.where(:parent_type => relatedTo, :parent_id => relatedParent.to_i) #, :project_id => params[:project_id].to_i
			else
				accPrtId = WkAccountProject.where(:parent_type => relatedTo, :parent_id => relatedParent.to_i, :project_id => projectId.to_i)
			end
			creditAmount = calInvPaidAmount(relatedTo, relatedParent, projectId, nil, false)
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
					@currency = params[:inv_currency]
					#setInvItemCurrency(apEntry)
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
				@invList[@listKey].store 'amount', (taxGrandTotal + grandTotal) + creditAmount
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
			@invItems[@itemCount].store 'currency', entry.currency
			@invItems[@itemCount].store 'item_quantity', 1
			@invItems[@itemCount].store 'item_amount', entry.amount.round(2)
			@itemCount = @itemCount + 1
			@currency = entry.currency
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
	
	def deleteBilledEntries(invItemIdsArr)
		CustomField.find(getSettingCfId('wktime_billing_id_cf')).custom_values.where(:value => invItemIdsArr).delete_all unless getSettingCfId('wktime_billing_id_cf').blank? || getSettingCfId('wktime_billing_id_cf') == 0
	end
	
	# def invreport
		# @invoice = WkInvoice.find(params[:invoice_id].to_i)
		# @invoiceItem = @invoice.invoice_items 
		# render :action => 'invreport', :layout => false
	# end
	
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
	
	def getPopulateChkBox
		l(:label_populate_unbilled_items)
	end
	
	def isInvGenUnbilledLink
		true
	end
	
	def isInvPaymentLink
		true
	end
	
	def getLabelInvNum
		l(:label_invoice_number)
	end
	
	def getLabelNewInv
		l(:label_new_invoice)
	end
	
	def getItemLabel
		l(:label_invoice_items)
	end
	
	def getDateLbl
		l(:label_invoice_date)
	end	
	
	def getOrderNumberPrefix
		'wktime_invoice_no_prefix'
	end
	
	def getNewHeaderLbl
		l(:label_new_invoice)
	end
	
	def getAutoPostModule
		'invoice'
	end
	
	def postableInvoice
		true
	end
	
	def deletePermission
		false
	end

end