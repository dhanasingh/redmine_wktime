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

	accept_api_auth :index, :edit, :update, :getInvProj, :getAccountProjIds
	@@invmutex = Mutex.new

	def newOrderEntity(parentId, parentType)	
		newInvoice(parentId, parentType)
	end

	def newInvoice(parentId, parentType)
		invoiceFreq = getInvFreqAndFreqStart
		invIntervals = getIntervals(params[:start_date].to_date, params[:end_date].to_date, invoiceFreq["frequency"], invoiceFreq["start"], true, false)
		if !params[:project_id].blank? && params[:project_id] != '0'
			@projectsDD = Project.where(:id => params[:project_id].to_i).pluck(:name, :id)				
			setTempEntity(invIntervals[0][0], invIntervals[0][1], parentId, parentType, params[:populate_items], params[:project_id])			
		elsif (!params[:project_id].blank? && params[:project_id] == '0') || params[:isAccBilling] == "true"
			accountProjects = WkAccountProject.where(:parent_type => parentType, :parent_id => parentId.to_i)	
			unless accountProjects.blank?
				@projectsDD = accountProjects[0].parent.projects.pluck(:name, :id)
				setTempEntity(invIntervals[0][0], invIntervals[0][1], parentId, parentType, params[:populate_items], params[:project_id])
			else
				client = parentType.constantize.find(parentId)
				flash[:error] = l(:warn_billable_project_not_configured, :name => client.name)
				redirect_to :action => 'new'
			end
		else
			flash[:error] = l(:warning_select_project)
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
	
	def getInvoicePeriod(startDate, endDate)
		[startDate, endDate]
	end
	
	def previewBilling(accountProjects, from, to)
		lastParentId = 0
		lastParentType = ""
		@currency = nil
		@listKey = 0
		@invList = Hash.new{|hsh,key| hsh[key] = {} }
		@previewBilling = true
		isActBilling = false
		totalInvAmt = 0
		invoiceFreq = getInvFreqAndFreqStart
		invIntervals = getIntervals(from, to, invoiceFreq["frequency"], invoiceFreq["start"], true, false)
		lastInvStart = nil
		invIntervals.each do |interval|
			accountProjects.each do |accProj|
				if isAccountBilling(accProj) 
					if (lastParentId != accProj.parent_id || lastParentType != accProj.parent_type) || lastInvStart != interval[0]
						setTempEntity(interval[0], interval[1], accProj.parent_id, accProj.parent_type, '1', '0')
						isActBilling = true
					end
					lastParentId = accProj.parent_id
					lastParentType = accProj.parent_type
					lastInvStart = interval[0]
				else
					isActBilling = false
					setTempEntity(interval[0], interval[1], accProj.parent_id, accProj.parent_type, '1', accProj.project_id)
				end
				
				if  (!@invList[@listKey]['amount'].blank? && @invList[@listKey]['amount'] != 0.0) 
					totQuantity = 0
					org_currency = ""
					@invItems.each do |key, value|
						totQuantity = totQuantity + value['item_quantity'] unless value['item_quantity'].blank?
						org_currency = value['currency']
					end
					@invList[@listKey].store 'invoice_number', ""
					@invList[@listKey].store 'parent_type', accProj.parent_type
					@invList[@listKey].store 'parent_id', accProj.parent_id
					@invList[@listKey].store 'name', accProj.parent.name
					@invList[@listKey].store 'project', @invItems[0]['project_id'].blank? ? accProj.project.name : Project.find(@invItems[0]['project_id']).name
					@invList[@listKey].store 'project_id', accProj.project_id
					@invList[@listKey].store 'status', 'o'
					@invList[@listKey].store 'quantity', totQuantity.round(4)
					@invList[@listKey].store 'start_date', interval[0]
					@invList[@listKey].store 'end_date', interval[1]
					@invList[@listKey].store 'isAccountBilling', isActBilling
					@invList[@listKey].store 'currency', org_currency
					totalInvAmt = totalInvAmt + @invList[@listKey]['amount']
					@listKey = @listKey + 1
				end
			end	
		end
		@entry_count = @invList.size
		setLimitAndOffset()
		invTotal = 0
		totlist = @invList.first(@limit*@entry_pages.page).last(@limit)
		totlist.each do |key, value|
			unless value.empty?
				amount = getExchangedAmount(value['currency'], value['amount'])
				invTotal = invTotal + amount
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
			totMatterialAmt = 0.00
			if !projectId.blank? && projectId == '0'
				accPrtId = WkAccountProject.where(:parent_type => relatedTo, :parent_id => relatedParent.to_i) 
			else
				accPrtId = WkAccountProject.where(:parent_type => relatedTo, :parent_id => relatedParent.to_i, :project_id => projectId.to_i)
			end
			creditAmount = calInvPaidAmount(relatedTo, relatedParent, projectId, nil, false)
			@taxVal = Hash.new{|hsh,key| hsh[key] = {} }
			@indexKey = 0
			totAmount = 0.00
			accPrtId.each do | apEntry|
				if !populatedItems.blank? && populatedItems == '1'
					@unbilled = true
					matterialAmt = 0
					if apEntry.billing_type == 'TM'
						totAmount = saveTAMInvoiceItem(apEntry, true)
						matterialAmt = addMaterialItem(apEntry, false) #.project_id
					else
						totAmount = getFcItems(apEntry, startDate, endDate)
					end									
					totMatterialAmt = totMatterialAmt + matterialAmt
				else
					@currency = params[:inv_currency]
				end
								
				grandTotal =  grandTotal + (totAmount.blank? ? 0.00 : totAmount)
				materialtotal = 100
				aptaxes = apEntry.taxes
				aptaxes.each do | taxEntry|	
					taxAmt =  (taxEntry.rate_pct/100) * (totAmount.blank? ? 0.00 : totAmount)
					@taxVal[@indexKey].store 'project_name', apEntry.project.name
					@taxVal[@indexKey].store 'name', taxEntry.name
					@taxVal[@indexKey].store 'rate', taxEntry.rate_pct
					@taxVal[@indexKey].store 'project_id', apEntry.project_id
					@taxVal[@indexKey].store 'currency', @currency
					@taxVal[@indexKey].store 'amount', taxAmt
					taxGrandTotal = taxGrandTotal + taxAmt
					@indexKey = @indexKey + 1
				end
				totAmount = 0.00
			end	
			
			unless (taxGrandTotal + grandTotal) == 0.0 && totMatterialAmt == 0.0
				@invList[@listKey].store 'amount', (taxGrandTotal + grandTotal + totMatterialAmt) + creditAmount
			end
	end
	
	def getFcItems(accountProject, startDate, endDate)
		totalAmt = 0		
		scheduledEntries = accountProject.wk_billing_schedules.where(:account_project_id => accountProject.id, :bill_date => startDate .. endDate, :invoice_id => nil)
		scheduledEntries.each do |entry|
			itemDesc = ""		
			if isAccountBilling(entry.account_project) 
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
			@invItems[@itemCount].store 'billing_type', entry.account_project.billing_type
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
				rateHash = getIssueRateHash(accProjectEntry.project.issues.first) #.custom_field_values
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
		#CustomField.find(getSettingCfId('wktime_billing_id_cf')).custom_values.where(:value => invItemIdsArr).delete_all unless getSettingCfId('wktime_billing_id_cf').blank? || getSettingCfId('wktime_billing_id_cf') == 0
		spents = WkSpentFor.where(:invoice_item_id => invItemIdsArr)
		spents.each do |spent|
			spent.update(:invoice_item_id => nil)
		end
		materialEntries = WkMaterialEntry.where(:invoice_item_id => invItemIdsArr)
		materialEntries.each do |mEntry|
			mEntry.update(:invoice_item_id => nil)
		end
	end
		
	def getAccountProjIds
		accProjId = getProjArrays(params[:parent_id], params[:parent_type] )
		accPjt = WkAccountProject.where(parent_id: params[:parent_id], parent_type: params[:parent_type])
		accProjs = ""
		accProjs << "0" + ',' + " " + "\n" if accPjt.present? && isAccountBilling(accPjt[0])

		respond_to do |format|
			format.text{
				(accProjId || []).each{ |proj| accProjs << proj.project_id.to_s() + ',' + proj.project_name.to_s()  + "\n" }
				render(plain: accProjs)
			}
			format.json{
				accProjs = []
				(accProjId || []).each{ |proj| accProjs << { value: proj.project_id, label: proj.project_name }}
				render(json: accProjs)
			}
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
		true
	end
	
	def addMaterialType
		true
	end
	
	def addAssetType
		true
	end
	
	def showProjectDD
		true
	end

	def addUnbilledItems
		true
	end

	def getQuantityDetails
		data = []
		dataTimeEntries = WkInvoiceItem.getSpentForEntries(params[:inv_item_id])
		dataTimeEntries.each{ |entry| data << {projID: entry.project_id, proj_name: entry.project.name, subject: entry.subject.to_s, usr_name: entry.firstname+''+entry.lastname, 				spent_on: entry.spent_on, hours: entry.hours}}
		render json: data
	end

	def getUnbilledQtyDetails
		data = []
		invoiceFreq = getInvFreqAndFreqStart
		invIntervals = getIntervals(params[:start_date].to_date, params[:end_date].to_date, invoiceFreq["frequency"], invoiceFreq["start"], true, false)
		fromDate = getUnbillEntryStart(invIntervals[0][0])
		todate = invIntervals[0][1]
		unbilledEntries = WkInvoiceItem.getUnbilledTimeEntries(params[:project_id], fromDate.to_date, todate.to_date, params[:parent_id], params[:parent_type])
		unbilledEntries = WkInvoiceItem.filterByIssues(unbilledEntries, params[:issue_id].to_i)
		unbilledEntries.each{ |entry| data << {projID: entry.project_id, proj_name: entry.project.name, subject: entry.issue.to_s, usr_name: entry.user.name, spent_on: entry.spent_on, hours: entry.hours} if entry.hours > 0}
    	render json: data
	end

	def generateTimeEntries
		data1 = []
		data2 = []
		data3 = []
		parent_type = ''
		parent_id = ''
		if params[:filter_type] == '2' && !params[:contactID].blank?
			parent_type = 'WkCrmContact'
			parent_id = 	params[:contactID]
		elsif params[:filter_type] == '2' && params[:contactID].blank?
			parent_type = 'WkCrmContact'
		end

		if params[:filter_type] == '3' && !params[:accID].blank?
			parent_type =  'WkAccount'
			parent_id = 	params[:accID]
		elsif params[:filter_type] == '3' && params[:accID].blank?
			parent_type =  'WkAccount'
		end

		invoiceFreq = getInvFreqAndFreqStart
		invIntervals = getIntervals(params[:fromDate].to_date, params[:dateval].to_date, invoiceFreq["frequency"], invoiceFreq["start"], true, false)
		fromDate = getUnbillEntryStart(invIntervals[0][0])
		todate = invIntervals[0][1]
		timeEntries = WkInvoiceItem.getGenerateEntries(todate.to_date, fromDate.to_date, parent_id, parent_type, params[:projectID], TimeEntry, 'time_entries')
		timeEntries.each{ |e| data1 << {id: e.id, acc_name: (e&.name || e&.c_name), proj_name: e&.project&.name, subject: e.issue.to_s, usr_name: e.user.name, spent_on: e.spent_on, hours: e.hours}}
		listHeader1 = { acc_cont_name: l(:field_account), project_name: l(:label_project), issue: l(:label_invoice_name), user: l(:label_user), date: l(:label_date), hour: l(:field_hours) }

		materialEntries = WkInvoiceItem.getGenerateEntries(todate.to_date, fromDate.to_date, parent_id, parent_type, params[:projectID], WkMaterialEntry, 'wk_material_entries')
		materialEntries.each{ |e| data2 << {id: e.id, acc_name: (e&.name || e&.c_name), project: e&.project&.name, issue: e.issue.to_s, spent_on: e.spent_on, product: e.inventory_item&.product_item&.product&.name, selling_price: e.currency.to_s+' '+e.selling_price.to_s, quantity: e.quantity }}
		listHeader2 = { acc_cont_name: l(:field_account), project_name: l(:label_project), issue: l(:label_invoice_name), date: l(:label_date), product_name: l(:field_inventory_item_id), selling_price: l(:label_selling_price), quantity: l(:field_quantity)}

		schudleEntries = WkInvoiceItem.getFcItems(invIntervals[0][0].to_date, todate.to_date, params[:projectID], parent_id, parent_type)
		schudleEntries.each{ |e| data3 << { acc_name: (e&.name || e&.c_name), project: e&.project&.name, issue: e&.milestone.to_s, spent_on: e.bill_date, amount: e&.currency+' '+e&.amount.to_s}}
		listHeader3 = { acc_cont_name: l(:field_account), project_name: l(:label_project), issue: l(:label_invoice_name), date: l(:label_date), amount: l(:field_amount)}
		render json: {data1: data1, listHeader1: listHeader1, data2: data2, listHeader2: listHeader2, data3: data3, listHeader3: listHeader3}
	end
	
	def invoice_components
		invoiceComp = WkInvoiceComponents.getInvComp
		@invComps = []
		@invComps = invoiceComp.map{|comp| [comp.name + '|' + comp.value.to_s, comp.id.to_s + '|' + comp.name + '|' + comp.value.to_s] } if invoiceComp.present?
	end

	def saveInvoiceComponents
		errorMsg = ""
		if params[:invoice]['comp_del_ids'].present?
			ids = params[:invoice]['comp_del_ids'].split('|')
			WkInvoiceComponents.where(id: ids.map(&:to_i)).destroy_all
		end
		invComps = params[:invoice_components] || []
		invComps.each do |component|
			if component.present?
				comp = component.split('|')
				wkInvoiceComps =  comp[0].present? ? WkInvoiceComponents.find(comp[0]) : WkInvoiceComponents.new
				wkInvoiceComps.comp_type = 'IC'
				wkInvoiceComps.name = comp[1]
				wkInvoiceComps.value = comp[2]
				if !wkInvoiceComps.save
					errorMsg += wkInvoiceComps.errors.full_messages.join("<br>")
				end
			end
		end
		if errorMsg.blank?
			flash[:notice] = l(:notice_successful_update)
	    else
			flash[:error] = errorMsg
	    end
			redirect_to action: 'invoice_components'
	end
end