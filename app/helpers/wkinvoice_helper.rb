module WkinvoiceHelper

include WktimeHelper

    def options_for_wktime_account()
		accArr = Array.new
		accArr << [ "", ""]
		accname = WkAccount.all
		if !accname.blank?
			accname.each do | entry|
				accArr << [ entry.name, entry.id ]
			end
		end
		accArr
	end
	
	def generateInvoices(accountId, projectId, invoiceDate,invoicePeriod)
		errorMsg = nil 
		@invoice = WkInvoice.new
		@invoice.status = 'o'
		@invoice.start_date = invoicePeriod[0]
		@invoice.end_date = invoicePeriod[1]
		@invoice.invoice_date = invoiceDate
		@invoice.modifier_id = User.current.id
		@invoice.project_id = projectId
		@invoice.account_id = accountId
		@invoice.invoice_number = "INV"
		if !@invoice.save
			errorMsg = @invoice.errors.full_messages.join('\n')
		else
			@invoice.invoice_number = "INV" + @invoice.id.to_s
			@invoice.save
			errorMsg = generateInvoiceItems()
		end
		errorMsg
	end
	
	def generateInvoiceItems()
		if @invoice.project_id.blank?
			WkAccountProject.where(account_id: @invoice.account_id).find_each do |accProj|
				addInvoiceItem(accProj)
			end
		else
			accountProject = WkAccountProject.where("account_id = ? and project_id = ?", @invoice.account_id, @invoice.project_id)
			addInvoiceItem(accountProject[0])
		end
		errorMsg = nil
		errorMsg
	end
	
	def addInvoiceItem(accountProject)
		if accountProject.billing_type == 'TAM'
			saveInvoiceItem(accountProject)
		else
			# TODO : Save invoice item for fixed cost
		end
	end
	
	def saveInvoiceItem(accountProject)
		rateHash = getProjectRateHash(accountProject.project.custom_field_values)
		timeEntries = TimeEntry.joins("left outer join custom_values on time_entries.id = custom_values.customized_id and custom_values.customized_type = 'TimeEntry'").where(project_id: accountProject.project_id, spent_on: @invoice.start_date .. @invoice.end_date).where("custom_values.value != '1'")
		totalAmount = 0
		lastUserId = 0
		lastIssueId = 0
		if rateHash.blank? || rateHash['rate'] <= 0
			sumEntry = timeEntries.group(:issue_id, :user_id).sum(:hours)
			userTotalHours = timeEntries.group(:user_id).sum(:hours)
			timeEntries.order(:issue_id, :user_id).each do |entry|
				updateBilledHours(entry)
				next if (lastUserId == entry.user_id && (lastIssueId == entry.issue_id || !accountProject.itemized_bill) )
				invItem = @invoice.wk_invoice_items.new()
				rateHash = getUserRateHash(entry.user.custom_field_values)
				lastUserId = entry.user_id
				lastIssueId = entry.issue_id
				if accountProject.itemized_bill
					description = entry.issue.subject + " - " + rateHash['designation']
					invItem = updateInvoiceItem(invItem, description, rateHash['rate'], sumEntry[[entry.issue_id, entry.user_id]], rateHash['currency'])
					totalAmount = totalAmount + invItem.amount
					
				else
					description = accountProject.project.name + " - " + rateHash['designation']
					invItem = updateInvoiceItem(invItem, description, rateHash['rate'], userTotalHours[entry.user_id], rateHash['currency'])
					totalAmount = totalAmount + invItem.amount
				end
			end
		else
			isContine = false
			sumEntry = timeEntries.group(:issue_id).sum(:hours)
			timeEntries.order(:issue_id).each do |entry|
				updateBilledHours(entry)
				next if lastIssueId == entry.issue_id || isContine
				lastIssueId = entry.issue_id
				invItem = @invoice.wk_invoice_items.new()
				if accountProject.itemized_bill
					invItem = updateInvoiceItem(invItem, entry.issue.subject, rateHash['rate'], sumEntry[entry.issue_id], rateHash['currency'])
					totalAmount = totalAmount + invItem.amount
					
				else
					isContine = true
					quantity = timeEntries.sum(:hours)
					invItem = updateInvoiceItem(invItem, accountProject.project.name, rateHash['rate'], quantity, rateHash['currency'])
					totalAmount = totalAmount + invItem.amount
				end
			end
		end
		if accountProject.apply_tax && totalAmount>0
			addTaxes(accountProject.project_id, rateHash['currency'], totalAmount)
		end		
	end
	
	def updateInvoiceItem(invItem, description, rate, quantity, currency)
		invItem.name = description
		invItem.rate = rate
		invItem.currency = currency
		invItem.quantity = quantity
		invItem.amount = invItem.rate * invItem.quantity
		invItem.modifier_id = User.current.id
		invItem.save()
		invItem
	end
	
	def updateBilledHours(tEntry)
		tEntry.custom_field_values = {getSettingCfId('wktime_billing_indicator_cf') => 1}
		tEntry.save		
	end
	
	def getProjectRateHash(projectCustVals)
		rateHash = Hash.new(2)
		projectCustVals.each do |custVal|
			case custVal.custom_field_id 
				when getSettingCfId('wktime_project_billing_rate_cf') 
					rateHash["rate"] = custVal.value.to_f
				when getSettingCfId('wktime_project_billing_currency_cf')  
					rateHash["currency"] = custVal.value
			end
		end
		rateHash
	end
	
	def getUserRateHash(userCustVals)
		rateHash = Hash.new(3)
		userCustVals.each do |custVal|
			case custVal.custom_field_id 
				when getSettingCfId('wktime_user_billing_rate_cf') 
					rateHash["rate"] = custVal.value.to_f
				when getSettingCfId('wktime_user_billing_currency_cf') 
					rateHash["currency"] = custVal.value
				when getSettingCfId('wktime_attn_designation_cf')
					rateHash["designation"] = custVal.value
			end
		end
		rateHash
	end
	
	def addTaxes(projectId, currency, totalAmount)
		projectTaxes = WkProjectTax.where(:project_id => projectId)
		projectTaxes.each do |projtax|
			invItem = @invoice.wk_invoice_items.new()
			invItem.name = projtax.project.name + ' - ' + projtax.tax.name
			invItem.rate = projtax.tax.rate.blank? ? 0 : projtax.tax.rate
			invItem.currency = currency
			invItem.quantity = nil
			invItem.amount = invItem.rate * totalAmount
			invItem.item_type = 't'
			invItem.modifier_id = User.current.id
			invItem.save()
		end
	end
end
