module WkinvoiceHelper
include WktimeHelper
include WkattendanceHelper

    def options_for_wktime_account(blankOption)
		accArr = Array.new
		if blankOption
		  accArr << [ "", ""]
		end
		accname = WkAccount.all
		if !accname.blank?
			accname.each do | entry|
				accArr << [ entry.name, entry.id ]
			end
		end
		accArr
	end
	
	def addInvoice(accountId, projectId, invoiceDate,invoicePeriod)
		@invoice = WkInvoice.new
		@invoice.status = 'o'
		@invoice.start_date = invoicePeriod[0]
		@invoice.end_date = invoicePeriod[1]
		@invoice.invoice_date = invoiceDate
		@invoice.modifier_id = User.current.id
		@invoice.account_id = accountId
		@invoice.invoice_number = getPluginSetting('wktime_invoice_no_prefix')
		if !@invoice.save
			errorMsg = @invoice.errors.full_messages.join("<br>")
		else
			@invoice.invoice_number = @invoice.invoice_number + @invoice.id.to_s
			@invoice.save
			errorMsg = generateInvoiceItems(projectId)
		end
		errorMsg
	end
	
	def generateInvoices(accountId, projectId, invoiceDate,invoicePeriod)
		errorMsg = nil
		account = WkAccount.find(accountId)
		if (projectId.blank? || projectId.to_i == 0)  && !account.account_billing
			account.projects.each do |project|
				errorMsg = addInvoice(accountId, project.id, invoiceDate,invoicePeriod)
			end
		else
			errorMsg = addInvoice(accountId, projectId, invoiceDate,invoicePeriod)
		end
		errorMsg
	end
	
	def generateInvoiceItems(projectId)
		if projectId.blank?  || projectId.to_i == 0
			WkAccountProject.where(account_id: @invoice.account_id).find_each do |accProj|
				addInvoiceItem(accProj)
			end
		else
			accountProject = WkAccountProject.where("account_id = ? and project_id = ?", @invoice.account_id, projectId)
			addInvoiceItem(accountProject[0])
		end
		errorMsg = nil
		errorMsg
	end
	
	def addInvoiceItem(accountProject)
		if accountProject.billing_type == 'TM'
			# Add invoice items for Time and Materiel cost
			saveTAMInvoiceItem(accountProject)
		else
			# Add invoice item for fixed cost from the scheduled entries
			scheduledEntries = accountProject.wk_billing_schedules.where(:account_project_id => accountProject.id, :bill_date => @invoice.start_date .. @invoice.end_date, :invoice_id => nil)
			totalAmount = 0
			scheduledEntries.each do |entry|
				invItem = saveFCInvoiceItem(entry)
				totalAmount = totalAmount + invItem.amount
				entry.invoice_id = @invoice.id
				entry.save
			end
			
			# Add Taxes for the account projects
			if accountProject.apply_tax && totalAmount>0
				addTaxes(accountProject, scheduledEntries[0].currency, totalAmount)
			end	
		end
	end
	
	# Add the invoice items for the scheduled entries
	def saveFCInvoiceItem(scheduledEntry)
		invItem = @invoice.invoice_items.new()
		itemDesc = ""
		if scheduledEntry.account_project.account.account_billing
			itemDesc = scheduledEntry.account_project.project.name + " - " + scheduledEntry.milestone
		else
			itemDesc = scheduledEntry.milestone
		end
		invItem = updateInvoiceItem(invItem, scheduledEntry.account_project.project_id, itemDesc, scheduledEntry.amount, 1, scheduledEntry.currency)
		invItem
	end
	
	# Add invoice items for the particular accountProject
	# Quantity calculate from the time entries for the project
	def saveTAMInvoiceItem(accountProject)
		# Get the rate and currency in rateHash
		rateHash = getProjectRateHash(accountProject.project.custom_field_values)
		genInvFrom = Setting.plugin_redmine_wktime['wktime_generate_invoice_from']
		genInvFrom = genInvFrom.blank? ? @invoice.start_date : genInvFrom.to_date
		timeEntries = TimeEntry.joins("left outer join custom_values on time_entries.id = custom_values.customized_id and custom_values.customized_type = 'TimeEntry' and custom_values.custom_field_id = #{getSettingCfId('wktime_billing_id_cf')}").where(project_id: accountProject.project_id, spent_on: genInvFrom .. @invoice.end_date).where("custom_values.value is null OR #{getSqlLengthQry("custom_values.value")} = 0 ")
		
		totalAmount = 0
		lastUserId = 0
		lastIssueId = 0
		lasInvItmId = nil # Used to update TimeEntry Billing Indicator CF
		# First check project has any rate if it didn't have rate then go with user rate
		if rateHash.blank? || rateHash['rate'] <= 0
			# calculate invoice based on the user rate
			# Calculate total hours for each issue each user 			
			sumEntry = timeEntries.group(:issue_id, :user_id).sum(:hours)
			userTotalHours = timeEntries.group(:user_id).sum(:hours)
			timeEntries.order(:issue_id, :user_id).each do |entry|
				rateHash = getUserRateHash(entry.user.custom_field_values)
				if rateHash.blank? || rateHash['rate'] <= 0
					next
				end
				if (lastUserId == entry.user_id && (lastIssueId == entry.issue_id || !accountProject.itemized_bill) )
					updateBilledHours(entry, lasInvItmId)
					next
				end
				invItem = @invoice.invoice_items.new()
				lastUserId = entry.user_id
				lastIssueId = entry.issue_id
				if accountProject.itemized_bill
					description = entry.issue.blank? ? entry.project.name : (accountProject.account.account_billing ? entry.project.name + ' - ' + entry.issue.subject : entry.issue.subject) + " - " + entry.user.membership(entry.project).roles[0].name
					invItem = updateInvoiceItem(invItem, accountProject.project_id, description, rateHash['rate'], sumEntry[[entry.issue_id, entry.user_id]], rateHash['currency'])
				else
					description = accountProject.project.name + " - " + entry.user.membership(entry.project).roles[0].name
					invItem = updateInvoiceItem(invItem, accountProject.project_id, description, rateHash['rate'], userTotalHours[entry.user_id], rateHash['currency'])
				end
				lasInvItmId = invItem.id
				updateBilledHours(entry, lasInvItmId)
				totalAmount = totalAmount + invItem.amount
			end
		else
			isContinue = false
			sumEntry = timeEntries.group(:issue_id).sum(:hours)
			timeEntries.order(:issue_id).each do |entry|
				if lastIssueId == entry.issue_id || isContinue
					updateBilledHours(entry, lasInvItmId)
					next 
				end
				lastIssueId = entry.issue_id
				invItem = @invoice.invoice_items.new()
				if accountProject.itemized_bill
					description =  entry.issue.blank? ? entry.project.name : (accountProject.account.account_billing ? entry.project.name + ' - ' + entry.issue.subject : entry.issue.subject)
					invItem = updateInvoiceItem(invItem, accountProject.project_id, description, rateHash['rate'], sumEntry[entry.issue_id], rateHash['currency'])
				else
					isContinue = true
					quantity = timeEntries.sum(:hours)
					invItem = updateInvoiceItem(invItem, accountProject.project_id, accountProject.project.name, rateHash['rate'], quantity, rateHash['currency'])
				end
				lasInvItmId = invItem.id
				updateBilledHours(entry, lasInvItmId)
				totalAmount = totalAmount + invItem.amount
			end
		end
		if accountProject.apply_tax && totalAmount>0
			addTaxes(accountProject, rateHash['currency'], totalAmount)
		end		
	end
	
	# Update invoice item by the given invoice item Object
	def updateInvoiceItem(invItem, projectId, description, rate, quantity, currency)
		invItem.project_id = projectId
		invItem.name = description
		invItem.rate = rate
		invItem.currency = currency
		invItem.quantity = quantity
		invItem.amount = invItem.rate * invItem.quantity
		invItem.modifier_id = User.current.id
		invItem.save()
		invItem
	end
	
	# Update timeEntry CF with invoice_item_id
	def updateBilledHours(tEntry, invItemId)
		tEntry.custom_field_values = {getSettingCfId('wktime_billing_id_cf') => invItemId}
		tEntry.save		
	end
	
	# Return RateHash which contains rate and currency for project
	def getProjectRateHash(projectCustVals)
		rateHash = Hash.new
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
	
	# Return RateHash which contains rate and currency for User
	def getUserRateHash(userCustVals)
		rateHash = Hash.new
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
	
	#Add Tax for the give accountProject
	def addTaxes(accountProject, currency, totalAmount)
		projectTaxes = accountProject.wk_acc_project_taxes
		projectTaxes.each do |projtax|
			invItem = @invoice.invoice_items.new()
			invItem.name = accountProject.project.name + ' - ' + projtax.tax.name
			invItem.rate = projtax.tax.rate_pct.blank? ? 0 : projtax.tax.rate_pct
			invItem.project_id = accountProject.project_id
			invItem.currency = currency
			invItem.quantity = nil
			invItem.amount = (invItem.rate/100) * totalAmount
			invItem.item_type = 't'
			invItem.modifier_id = User.current.id
			invItem.save()
		end
	end
	
	# Return the Query string with SQL length function for the given column
	def getSqlLengthQry(column)
		if ActiveRecord::Base.connection.adapter_name == 'SQLServer'			 
			lenSqlQry = "len(#{column})"
		else
			lenSqlQry = "length(#{column})"
		end		
		lenSqlQry
	end
	
	# Name of the numbers in Hash
	def getNumberAsStr
		numbers_name_hash = {
		  1000000000000 => l(:label_trillion),
		  1000000000 => l(:label_billion),
		  1000000 => l(:label_million),
		  1000 => l(:label_thousand),
		  100 => l(:label_hundred),
		  90 => l(:label_ninety),
		  80 => l(:label_eighty),
		  70 => l(:label_seventy),
		  60 => l(:label_sixty),
		  50 => l(:label_fifty),
		  40 => l(:label_forty),
		  30 => l(:label_thirty),
		  20 => l(:label_twenty),
		  19=> l(:label_nineteen),
		  18=> l(:label_eighteen),
		  17=> l(:label_seventeen), 
		  16=> l(:label_sixteen),
		  15=> l(:label_fifteen),
		  14=> l(:label_fourteen),
		  13=> l(:label_thirteen),              
		  12=> l(:label_twelve),
		  11=> l(:label_eleven),
		  10=> l(:label_ten),
		  9 => l(:label_nine),
		  8 => l(:label_eight),
		  7 => l(:label_seven),
		  6 => l(:label_six),
		  5 => l(:label_five),
		  4 => l(:label_four),
		  3 => l(:label_three),
		  2 => l(:label_two),
		  1 => l(:label_one)
		}
	end
	
	# Return the given number in words
	def numberInWords (numVal)
		totalNoOfDigits = (numVal.to_i.to_s).length
		quad = numVal.to_i
		numValStr = ""
		while quad > 0 do
			quadDigits = (quad.to_s).length
			currentUnit = 10 ** (totalNoOfDigits - quadDigits)
			currStr = nil
			currStr = getThreeDigitNumberStr((quad%1000))
			quad = quad/1000
			unless currStr.blank?
				currStr = currStr + " " + (currentUnit == 1 ? "" : getNumberAsStr[currentUnit])
				numValStr = numValStr.blank? || currStr.blank?  ? currStr + numValStr :  currStr + "" + numValStr
			end
		end
		numValStr.lstrip.capitalize
	end
	
	# Return the Two digit number in words
	def getTwoDigitNumberStr(twoDigitVal)
		numStr = ""
		unless getNumberAsStr[twoDigitVal].blank?
			numStr = getNumberAsStr[twoDigitVal]
		else
			if twoDigitVal > 0
				numStr = getNumberAsStr[(twoDigitVal.to_i/10)*10] + " " + getNumberAsStr[twoDigitVal%10]
			end
		end
		numStr = " " + numStr unless numStr.blank?
		numStr
	end
	
	# Return the Three digit number in words
	def getThreeDigitNumberStr(thrDigitVal)
		numStr = ""
		unless getNumberAsStr[thrDigitVal].blank?
			numStr = getNumberAsStr[thrDigitVal]
		else
			if thrDigitVal > 0
				hundredStr = getNumberAsStr[thrDigitVal/100].blank? ? "" : (getNumberAsStr[thrDigitVal/100] + " hundred ")
				twoDigStr = getTwoDigitNumberStr(thrDigitVal%100)
				numStr = hundredStr.blank? || twoDigStr.blank? ? (hundredStr + twoDigStr)  : (hundredStr + "and" + twoDigStr)
			end
		end
		numStr = " " + numStr unless numStr.blank?
		numStr
	end
end
