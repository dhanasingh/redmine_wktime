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

module WkinvoiceHelper
include WktimeHelper
include WkattendanceHelper
include WkaccountingHelper
include WkgltransactionHelper
include WkbillingHelper


    def options_for_wktime_account(blankOption, accountType)
		accArr = Array.new
		if blankOption
		  accArr << [ "", ""]
		end
		accname = WkAccount.where(:account_type => accountType).order(:name)
		if !accname.blank?
			accname.each do | entry|
				accArr << [ entry.name, entry.id ]
			end
		end
		accArr
	end
	
	def addInvoice(parentId, parentType,  projectId, invoiceDate,invoicePeriod, isgenerate, invoiceType)
		@invoice = WkInvoice.new
		@invoice.status = 'o'
		@invoice.start_date = invoicePeriod[0]
		@invoice.end_date = invoicePeriod[1]
		@invoice.invoice_date = invoiceDate
		@invoice.modifier_id = User.current.id
		@invoice.parent_id = parentId
		@invoice.parent_type = parentType
		@invoice.invoice_type = invoiceType unless invoiceType.blank?
		@invoice.invoice_number = getPluginSetting(getOrderNumberPrefix)
		unless isgenerate
			errorMsg = saveInvoice
		else			
			errorMsg = generateInvoiceItems(projectId)
		end
		
		unless @invoice.id.blank?
			totalAmount = @invoice.invoice_items.sum(:amount)
			invoiceAmount = @invoice.invoice_items.where.not(:item_type => 'm').sum(:amount)
			# moduleAmtHash key - module name , value - [crAmount, dbAmount]
			moduleAmtHash = {'material' => [totalAmount.round - invoiceAmount.round, nil], getAutoPostModule => [invoiceAmount.round, totalAmount.round]}
			
			transAmountArr = getTransAmountArr(moduleAmtHash)
			if (totalAmount.round - totalAmount) != 0
				addRoundInvItem(totalAmount)
			end
			if totalAmount > 0 && autoPostGL(getAutoPostModule)
				transId = @invoice.gl_transaction.blank? ? nil : @invoice.gl_transaction.id
				glTransaction = postToGlTransaction('invoice', transId, @invoice.invoice_date, transAmountArr, @invoice.invoice_items[0].currency, nil, nil)
				unless glTransaction.blank?
					@invoice.gl_transaction_id = glTransaction.id
					@invoice.save
				else
					errorMsg = Hash.new
					errorMsg['trans'] = l(:error_trans_msg)
				end				
			end
		end
		errorMsg
	end
	
	# def postToGlTransaction(invoice, amount, currency)
		# glTransaction = nil
		# crLedger = WkLedger.where(:id => getSettingCfId('invoice_cr_ledger'))
		# dbLedger = WkLedger.where(:id => getSettingCfId('invoice_db_ledger'))
		# unless crLedger[0].blank? || dbLedger[0].blank?
			# transId = invoice.gl_transaction.blank? ? nil : invoice.gl_transaction.id
			# transType = getTransType(crLedger[0].ledger_type, dbLedger[0].ledger_type)
			# if Setting.plugin_redmine_wktime['wktime_currency'] == currency 
				# isDiffCur = false 
			# else
				# isDiffCur = true 
			# end
			# glTransaction = saveGlTransaction(transId, invoice.invoice_date, transType, nil, amount, currency, isDiffCur)
		# end
		# glTransaction
	# end
	
	def saveInvoice
		errorMsg = nil
		unless @invoice.save
			errorMsg = @invoice.errors.full_messages.join("<br>")
		# else
			# @invoice.invoice_number = @invoice.invoice_number + @invoice.invoice_num_key.to_s#@invoice.id.to_s
			# @invoice.save
		 end
		errorMsg
	end
		
	def generateInvoices(billProject, projectId, invoiceDate,invoicePeriod)#parentId, parentType
		errorMsg = nil
		#account = nil
		#account = WkAccount.find(parentId) unless parentType == 'WkCrmContact'
		if (projectId.blank? || projectId.to_i == 0)  && !isAccountBilling(billProject)#account.account_billing 
			billProject.parent.projects.each do |project|
				errorMsg = addInvoice(billProject.parent_id, billProject.parent_type, project.id, invoiceDate,invoicePeriod, true, nil)
			end
		else
			errorMsg = addInvoice(billProject.parent_id, billProject.parent_type, projectId, invoiceDate,invoicePeriod, true, nil)
		end
		errorMsg
	end
	
	def generateInvoiceItems(projectId)		
		if projectId.blank?  || projectId.to_i == 0
			WkAccountProject.where(parent_id: @invoice.parent_id, parent_type: @invoice.parent_type).find_each do |accProj|
				errorMsg = addInvoiceItem(accProj)
			end
		else
			accountProject = WkAccountProject.where("parent_id = ? and parent_type = ? and project_id = ?", @invoice.parent_id, @invoice.parent_type, projectId)
			errorMsg = addInvoiceItem(accountProject[0])
		end
		errorMsg
	end
	
	def addInvoiceItem(accountProject)
		if accountProject.billing_type == 'TM'
			# Add invoice items for Time and Materiel cost
			errorMsg = saveTAMInvoiceItem(accountProject, false)
		else
			# Add invoice item for fixed cost from the scheduled entries
			errorMsg = nil
			genInvFrom = Setting.plugin_redmine_wktime['wktime_generate_invoice_from']
			genInvFrom = genInvFrom.blank? ? @invoice.start_date : genInvFrom.to_date
			scheduledEntries = accountProject.wk_billing_schedules.where(:account_project_id => accountProject.id, :bill_date => genInvFrom .. @invoice.end_date, :invoice_id => nil)
			totalAmount = 0
			scheduledEntries.each do |entry|
				if @invoice.id.blank?
					errorMsg = saveInvoice
					unless errorMsg.blank?
						break
					end
				end
				invItem = saveFCInvoiceItem(entry)
				totalAmount = totalAmount + invItem.amount
				entry.invoice_id = @invoice.id
				entry.save
			end
			#Add Previous Invoice credit amount
			creditAmount = calInvPaidAmount(@invoice.parent_type,  @invoice.parent_id, accountProject.project_id, @invoice.id, true)
			# Add Taxes for the account projects
			if accountProject.apply_tax && totalAmount>0
				addTaxes(accountProject, scheduledEntries[0].currency, totalAmount)
			end	
		end
		addMaterialItem(accountProject.project_id, true)
		errorMsg
	end
	
	# Add the invoice items for the scheduled entries
	def saveFCInvoiceItem(scheduledEntry)
		invItem = @invoice.invoice_items.new()
		itemDesc = ""		
		if isAccountBilling(scheduledEntry.account_project) #scheduledEntry.account_project.parent.account_billing
			itemDesc = scheduledEntry.account_project.project.name + " - " + scheduledEntry.milestone
		else
			itemDesc = scheduledEntry.milestone
		end
		invItem = updateInvoiceItem(invItem, scheduledEntry.account_project.project_id, itemDesc, scheduledEntry.amount, 1, scheduledEntry.currency, 'i',scheduledEntry.amount, nil, nil, nil )
		invItem
	end
	
	# Add invoice items for the particular accountProject
	# Quantity calculate from the time entries for the project
	def saveTAMInvoiceItem(accountProject, isCreate)
		# Get the rate and currency in rateHash
		rateHash = getProjectRateHash(accountProject.project.custom_field_values)
		genInvFrom = Setting.plugin_redmine_wktime['wktime_generate_invoice_from']
		genInvFrom = genInvFrom.blank? ? @invoice.start_date : genInvFrom.to_date
		timeEntries = TimeEntry.joins("left outer join custom_values on time_entries.id = custom_values.customized_id and custom_values.customized_type = 'TimeEntry' and custom_values.custom_field_id = #{getSettingCfId('wktime_billing_id_cf')}").where(project_id: accountProject.project_id, spent_on: genInvFrom .. @invoice.end_date).where("custom_values.value is null OR #{getSqlLengthQry("custom_values.value")} = 0 ")
		
		errorMsg = nil
		totalAmount = 0
		lastUserId = 0
		lastIssueId = 0
		#hashKey = 0
		itemAmount = 0
		oldIssueId = 0
		lasInvItmId = nil # Used to update TimeEntry Billing Indicator CF
		#@invItems = Hash.new{|hsh,key| hsh[key] = {} }
		# First check project has any rate if it didn't have rate then go with user rate
		if rateHash.blank? || rateHash['rate'].blank? || rateHash['rate'] <= 0
			userIdVal =  Array.new
			# calculate invoice based on the user rate
			# Calculate total hours for each issue each user 
			description = ""	
			quantity = 0
			sumEntry = timeEntries.group(:issue_id, :user_id).sum(:hours)
			issueSumEntry = timeEntries.group(:issue_id).sum(:hours)
			userTotalHours = timeEntries.group(:user_id).sum(:hours)
			timeEntries.order(:issue_id, :user_id, :id).each_with_index do |entry, index|
				#rateHash = getUserRateHash(entry.user.custom_field_values)
				unless entry.issue.blank?
					rateHash = getIssueRateHash(entry.issue.custom_field_values)
				else
					rateHash = nil
				end
				@currency = rateHash['currency'] unless rateHash.blank?
				isUserBilling = false
				if rateHash.blank? || rateHash['rate'].blank? || rateHash['rate'] <= 0
					rateHash = getUserRateHash(entry.user.custom_field_values)
					@currency = rateHash['currency']
					isUserBilling = true
					if rateHash.blank? || rateHash['rate'].blank? || rateHash['rate'] <= 0
						next
					end		
				end
				if ((lastUserId == entry.user_id && (lastIssueId == entry.issue_id || !accountProject.itemized_bill)) || (lastIssueId == entry.issue_id && !isUserBilling)) && !isCreate
					updateBilledHours(entry, lasInvItmId) 
					next
				end
				if @invoice.id.blank? && !isCreate
					errorMsg = saveInvoice
					unless errorMsg.blank?
						break
					end
				end
				invItem = @invoice.invoice_items.new()
				#lastUserId = entry.user_id
				lastIssueId = entry.issue_id
				if isUserBilling
					if accountProject.itemized_bill
						description = entry.issue.blank? ? entry.project.name : (isAccountBilling(accountProject) ? entry.project.name + ' - ' + entry.issue.subject : entry.issue.subject) + " - " + entry.user.membership(entry.project).roles[0].name
						quantity = sumEntry[[entry.issue_id, entry.user_id]]
						amount = rateHash['rate'] * quantity
						invItem = updateInvoiceItem(invItem, accountProject.project_id, description, rateHash['rate'], quantity, rateHash['currency'], 'i', amount, nil, nil, nil) unless isCreate
					else
						description = accountProject.project.name + " - " + entry.user.membership(entry.project).roles[0].name
						quantity = userTotalHours[entry.user_id]
						amount = rateHash['rate'] * quantity
						invItem = updateInvoiceItem(invItem, accountProject.project_id, description, rateHash['rate'], quantity, rateHash['currency'], 'i', amount, nil, nil, nil) unless isCreate
					end
				else
					description = entry.issue.blank? ? entry.project.name : (isAccountBilling(accountProject) ? entry.project.name + ' - ' + entry.issue.subject : entry.issue.subject) 
					quantity = issueSumEntry[entry.issue_id]
					amount = rateHash['rate'] * quantity
					invItem = updateInvoiceItem(invItem, accountProject.project_id, description, rateHash['rate'], quantity, rateHash['currency'], 'i', amount, nil, nil, nil) unless isCreate
				end
				
				if isCreate && ((oldIssueId != 0 && oldIssueId != entry.issue_id) || (timeEntries.order(:issue_id, :user_id, :id).last == entry) || (timeEntries.order(:issue_id, :user_id, :id).length == (index+1))  )
					keyVal = timeEntries.order(:issue_id, :user_id, :id).first == entry ? @itemCount : @itemCount - 1					  
					userIdVal << entry.id if timeEntries.order(:issue_id, :user_id, :id).last == entry || timeEntries.order(:issue_id, :user_id, :id).length == (index+1)
					@invItems[keyVal].store 'milestone_id', userIdVal 
					userIdVal= []
				end
				userIdVal << entry.id
				if isCreate && ((oldIssueId == 0 || oldIssueId != entry.issue_id) || (isUserBilling && lastUserId != entry.user_id))		
					itemAmount = rateHash['rate'] * quantity
					@invItems[@itemCount].store 'project_id', accountProject.project_id
					@invItems[@itemCount].store 'item_desc', description
					@invItems[@itemCount].store 'item_type', 'i'
					@invItems[@itemCount].store 'rate', rateHash['rate']
					@invItems[@itemCount].store 'currency', rateHash['currency']
					@invItems[@itemCount].store 'item_quantity', quantity
					@invItems[@itemCount].store 'item_amount', itemAmount
					@itemCount = @itemCount + 1
					oldIssueId = entry.issue_id
					totalAmount = (totalAmount + itemAmount).round(2)
					errorMsg = totalAmount
				end
				lastUserId = entry.user_id
				lasInvItmId = invItem.id unless isCreate
				updateBilledHours(entry, lasInvItmId) unless isCreate
				totalAmount = totalAmount + invItem.amount unless isCreate
			end
		else
			pjtIdVal = Array.new
			pjtOldIdArr =  Array.new
			isContinue = false
			pjtDescription = ""
			pjtQuantity = 0			
			@currency = rateHash['currency']
			sumEntry = timeEntries.group(:issue_id).sum(:hours)
			timeEntries.order(:issue_id).each_with_index do |entry, index|
				if (lastIssueId == entry.issue_id || isContinue) && !isCreate
					updateBilledHours(entry, lasInvItmId)
					next 
				end
				lastIssueId = entry.issue_id
				if @invoice.id.blank? && !isCreate
					errorMsg = saveInvoice
					unless errorMsg.blank?
						break
					end
				end
				invItem = @invoice.invoice_items.new()
				if accountProject.itemized_bill					
					pjtDescription =  entry.issue.blank? ? entry.project.name : (isAccountBilling(accountProject) ? entry.project.name + ' - ' + entry.issue.subject : entry.issue.subject)
					pjtQuantity = sumEntry[entry.issue_id]
					amount = rateHash['rate'] * pjtQuantity
					invItem = updateInvoiceItem(invItem, accountProject.project_id, pjtDescription, rateHash['rate'], pjtQuantity, rateHash['currency'], 'i', amount, nil, nil, nil) unless isCreate
				else
					isContinue = true
					pjtQuantity = timeEntries.sum(:hours)
					pjtDescription = accountProject.project.name
					amount = rateHash['rate'] * pjtQuantity
					invItem = updateInvoiceItem(invItem, accountProject.project_id, pjtDescription, rateHash['rate'], pjtQuantity, rateHash['currency'], 'i', amount, nil, nil, nil) unless isCreate
				end
				if isCreate && ((oldIssueId != 0 && oldIssueId != entry.issue_id) || (timeEntries.order(:issue_id).last == entry) || (timeEntries.order(:issue_id).length == (index+1)  ))
					keyVal = timeEntries.order(:issue_id).first == entry ? @itemCount : @itemCount - 1
					pjtIdVal << entry.id if timeEntries.order(:issue_id).last == entry || timeEntries.order(:issue_id).length == (index+1)
					@invItems[keyVal].store 'milestone_id', pjtIdVal 
					pjtIdVal= []
				end
				pjtIdVal << entry.id
				
    			 if isCreate && (oldIssueId == 0 || oldIssueId != entry.issue_id)
					itemAmount = rateHash['rate'] * pjtQuantity
					#@invItems[@itemCount].store 'milestone_id', entry.id				
					@invItems[@itemCount].store 'project_id', accountProject.project_id
					@invItems[@itemCount].store 'item_desc', pjtDescription
					@invItems[@itemCount].store 'item_type', 'i'
					@invItems[@itemCount].store 'rate', rateHash['rate']
					@invItems[@itemCount].store 'currency', rateHash['currency']
					@invItems[@itemCount].store 'item_quantity', pjtQuantity.round(2)
					@invItems[@itemCount].store 'item_amount', itemAmount.round(2)
					@itemCount = @itemCount + 1
					oldIssueId = entry.issue_id
					totalAmount = (totalAmount + itemAmount).round(2)
					errorMsg = totalAmount
				end
				lasInvItmId = invItem.id unless isCreate
				updateBilledHours(entry, lasInvItmId) unless isCreate
				totalAmount = totalAmount + invItem.amount unless isCreate
			end			
		end
		creditAmount = calInvPaidAmount(@invoice.parent_type,  @invoice.parent_id, accountProject.project_id, @invoice.id, true) unless isCreate
		if accountProject.apply_tax && totalAmount>0 && !isCreate
			addTaxes(accountProject, rateHash['currency'], totalAmount)
		end
		errorMsg
	end
	
	# Update invoice item by the given invoice item Object
	def updateInvoiceItem(invItem, projectId, description, rate, quantity, currency, itemType, amount, creditInvoiceId, crPaymentItemId, productId)
		invItem.project_id = projectId
		invItem.name = description
		invItem.rate = rate 
		invItem.currency = currency
		invItem.quantity = quantity
		invItem.item_type = itemType unless itemType.blank?
		invItem.amount = amount #invItem.rate * invItem.quantity
		invItem.modifier_id = User.current.id
		invItem.product_id = productId
		invItem.credit_invoice_id = creditInvoiceId unless creditInvoiceId.blank?
		invItem.credit_payment_item_id = crPaymentItemId unless crPaymentItemId.blank?
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
	
	# Return RateHash which contains rate and currency for Issue
	def getIssueRateHash(projectCustVals)
		rateHash = Hash.new
		projectCustVals.each do |custVal|
			case custVal.custom_field_id 
				when getSettingCfId('wktime_issue_billing_rate_cf') 
					rateHash["rate"] = custVal.value.to_f
				when getSettingCfId('wktime_issue_billing_currency_cf')  
					rateHash["currency"] = custVal.value
			end
		end
		rateHash
	end
	
	#Add Tax for the give accountProject
	def addTaxes(accountProject, currency, totalAmount)
		unless accountProject.blank?
			projectTaxes = accountProject.wk_acc_project_taxes
			projectTaxes.each do |projtax|
				invItem = @invoice.invoice_items.new()
				rate = projtax.tax.rate_pct.blank? ? 0 : projtax.tax.rate_pct
				amount = (rate/100) * totalAmount
				updateInvoiceItem(invItem, accountProject.project_id, projtax.tax.name, rate, nil, currency, 't', amount, nil, nil, nil) 			
			end
		end
	end
	
	# Add an invoice item for the round off value
	def addRoundInvItem(totalAmount)
		invItem = @invoice.invoice_items.new()		
		updateInvoiceItem(invItem, @invoice.invoice_items[0].project_id, l(:label_round_off), nil, nil, @invoice.invoice_items[0].currency, 'r', (totalAmount.round - totalAmount), nil, nil, nil)		
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
		isNegativeNum = false
		if numVal<0
			isNegativeNum = true
			numVal = numVal*(-1)
		end
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
		numValStr = l(:label_minus) + " " + numValStr if isNegativeNum
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
				hundredStr = getNumberAsStr[thrDigitVal/100].blank? ? "" : (getNumberAsStr[thrDigitVal/100] + " " +  l(:label_hundred))
				twoDigStr = getTwoDigitNumberStr(thrDigitVal%100)
				numStr = hundredStr.blank? || twoDigStr.blank? ? (hundredStr + twoDigStr)  : (hundredStr + " "+ l('support.array.sentence_connector') + twoDigStr)
			end
		end
		numStr = " " + numStr unless numStr.blank?
		numStr
	end
	
	def autoPostGL(transModule)
		(!Setting.plugin_redmine_wktime["#{transModule}_auto_post_gl"].blank? && Setting.plugin_redmine_wktime["#{transModule}_auto_post_gl"].to_i == 1)
	end
	
	def isAccountBilling(accountProject)
		ret = false
		if accountProject.parent_type == 'WkAccount'
			ret = accountProject.parent.account_billing
		end
		ret
	end
	
	def calInvPaidAmount(parentType, parentId, projectId, invoiceId, isCreate)
		totalCreditAmount = 0
		queryString = "select inv.*,i.parent_id, i.parent_type, iit.project_id, iit.currency, pit.id as payment_item_id, pit.amount, pit.payment_id, pay.paid_amount, coalesce(inv.inv_amount - pay.paid_amount, inv.inv_amount , - pay.paid_amount) as total_credit,
		 pcr.given_pay_credit, icr.given_inv_credit,
		 coalesce(inv.inv_amount - pay.paid_amount, inv.inv_amount , - pay.paid_amount, 0) -  coalesce(pcr.given_pay_credit, 0) -  coalesce(icr.given_inv_credit, 0)  as available_pay_credit from
		(select i.id, sum(it.amount) inv_amount
		from wk_invoices i
		left outer join wk_invoice_items it on i.id = it.invoice_id
		group by i.id) inv
		left join (select sum(amount) paid_amount, invoice_id from wk_payment_items where is_deleted = #{false} group by invoice_id) pay on pay.invoice_id = inv.id
		left join wk_payment_items pit on(inv.id = pit.invoice_id and pit.is_deleted = #{false})
		left join (select gcr.*, invitm.invoice_id from (select sum(amount) given_pay_credit, credit_payment_item_id from wk_invoice_items
		where credit_payment_item_id is not null group by credit_payment_item_id) gcr
		left join wk_payment_items invitm on (invitm.id = gcr.credit_payment_item_id and invitm.is_deleted = #{false})) pcr on (pcr.credit_payment_item_id = pit.id OR  pcr.invoice_id = inv.id)
		left join (select sum(amount) given_inv_credit, credit_invoice_id from wk_invoice_items
		where credit_invoice_id is not null group by credit_invoice_id) icr on (icr.credit_invoice_id = inv.id)
		left join wk_invoices i on i.id = inv.id
		left join (select i.id, min(it.id) as inv_item_id
		from wk_invoices i
		left outer join wk_invoice_items it on i.id = it.invoice_id
		group by i.id) fit on fit.id = inv.id
		left join wk_invoice_items iit on iit.id = fit.inv_item_id
		where coalesce(inv.inv_amount - pay.paid_amount, inv.inv_amount , - pay.paid_amount, 0) -  coalesce(pcr.given_pay_credit, 0) -  coalesce(icr.given_inv_credit, 0) < 0 and i.parent_type= '#{parentType}' and i.parent_id = #{parentId}   "
		if !invoiceId.blank? && invoiceId != '0'
			queryString = queryString + " and inv.id != #{invoiceId}"
		end
		if !projectId.blank? && projectId != '0'
			queryString = queryString + " and iit.project_id = #{projectId}"	
		end 
		queryString = queryString + " order by inv.id, pit.id desc"
		#queryString = queryString + " group by i.id "
		invEntry = WkInvoice.find_by_sql(queryString)
		lastInvId = nil
		invEntry.each do | entry |
			if lastInvId == entry.id
				next
			end
			if !entry.available_pay_credit.blank? &&  entry.available_pay_credit != 0
				@invItems[@itemCount].store 'project_id', entry.project_id
				@invItems[@itemCount].store 'item_type', 'c'
				@invItems[@itemCount].store 'rate', entry.available_pay_credit
				@invItems[@itemCount].store 'item_quantity', 1
				@invItems[@itemCount].store 'currency', entry.currency
				@invItems[@itemCount].store 'item_amount', entry.available_pay_credit
				totalCreditAmount = totalCreditAmount + entry.available_pay_credit
				credit_invoice_id = nil
				creditDesc = ""
				if entry.inv_amount < 0
					credit_invoice_id = entry.id
					@invItems[@itemCount].store 'milestone_id', entry.id
					@invItems[@itemCount].store 'creditfromInvoice', true
					creditDesc = l(:label_credit_from_prv_inv, :invId => entry.id)
				else
					@invItems[@itemCount].store 'milestone_id', entry.payment_item_id
					@invItems[@itemCount].store 'creditfromInvoice', false
					creditDesc =  l(:label_credit_from_prv_inv_pay, :invId => entry.id, :payId => entry.payment_item_id)
				end
				@invItems[@itemCount].store 'item_desc', creditDesc
				
				if isCreate
					invItem = WkInvoiceItem.new
					invItem.invoice_id = invoiceId
					updateInvoiceItem(invItem, entry.project_id, creditDesc, entry.available_pay_credit, 1, entry.currency, 'c', entry.available_pay_credit, credit_invoice_id, entry.payment_item_id, nil)
				end
				@itemCount = @itemCount + 1
			end
			lastInvId = entry.id
		end
		totalCreditAmount
	end
	
	def isEditableInvoice(invoiceId)
		isEditable = true
		issuedCrCount = WkInvoiceItem.where(:credit_invoice_id => invoiceId).count
		invoicePayCount = WkPaymentItem.where(:invoice_id => invoiceId).count
		isEditable = false if issuedCrCount>0 || invoicePayCount>0
		isEditable
	end
	
	def addMaterialItem(accountProject, isCreate)		
		productArr = Array.new
		invItem = nil
		@totalMatterialAmount = 0.00
		partialMatAmount = 0.00
		@matterialVal = Hash.new{|hsh,key| hsh[key] = {} }
		matterialEntry = WkMaterialEntry.where(:project_id => accountProject, :invoice_item_id => nil)
			matterialEntry.each do | mEntry |
				invItem = @invoice.invoice_items.new()			
				productId = mEntry.inventory_item.product_item.product.id
				productName = mEntry.inventory_item.product_item.product.name.to_s
				productArr << productId
				desc = productName + " " + mEntry.inventory_item.product_item.brand.name.to_s + " " + mEntry.inventory_item.product_item.product_model.name.to_s
				rate = mEntry.selling_price
				qty = mEntry.quantity
				curr = mEntry.inventory_item.currency
				amount = mEntry.selling_price * mEntry.quantity
				if @matterialVal.has_key?("#{productId}")
					oldAmount = @matterialVal["#{productId}"]["amount"].to_i
					totAmount = oldAmount + amount
					@matterialVal["#{productId}"].store "amount", "#{totAmount}"
				else
					@matterialVal["#{productId}"].store "amount", "#{amount}"
					@matterialVal["#{productId}"].store "currency", "#{curr}"
					@matterialVal["#{productId}"].store "pname", "#{productName}"
					@matterialVal["#{productId}"].store "projectId", "#{mEntry.project_id}"
					@matterialVal["#{productId}"].store "projectName", "#{mEntry.project.name}"
				end
				@invItems[@itemCount].store 'milestone_id', ''				
				@invItems[@itemCount].store 'project_id', mEntry.project_id
				@invItems[@itemCount].store 'product_id', productId
				@invItems[@itemCount].store 'material_id', mEntry.id
				@invItems[@itemCount].store 'item_desc', desc
				@invItems[@itemCount].store 'item_type', 'm'
				@invItems[@itemCount].store 'rate', rate
				@invItems[@itemCount].store 'currency', curr
				@invItems[@itemCount].store 'item_quantity', qty.round(2)
				@invItems[@itemCount].store 'item_amount', amount
				@itemCount = @itemCount + 1
				partialMatAmount = partialMatAmount + amount.round(2)
				if isCreate
					invItem = updateInvoiceItem(invItem, mEntry.project_id, desc, rate, qty, curr, 'm', amount, nil, nil, productId) 
					updateMatterial = WkMaterialEntry.find(mEntry.id)
					updateMatterial.invoice_item_id = invItem.id
					updateMatterial.save()
				end
			end
			@totalMatterialAmount =  partialMatAmount.round(2)
			addProductTaxes(productArr, isCreate)			
			
			@totalMatterialAmount.round(2)
	end
	
	def addProductTaxes(productArr, isCreate)
		pdtArr = productArr.uniq			
		pdtArr.each do | pid |
			pdtTaxesId = WkProductTax.where(:product_id => pid) #.pluck(:id)
			pdtTaxesId.each do | tid |
				taxinvItem = @invoice.invoice_items.new()
				projectId = @matterialVal["#{pid}"]["projectId"]  #invItem.project_id
				curr = @matterialVal["#{pid}"]["currency"] #invItem.currency 
				taxName = tid.tax.name.blank? ? " " : tid.tax.name
				rate = tid.tax.rate_pct.blank? ? 0 : tid.tax.rate_pct
				amount = (rate/100) * @matterialVal["#{pid}"]["amount"].to_i
				desc = @matterialVal["#{pid}"]["pname"] + " - " + taxName.to_s
				
				@totalMatterialAmount = @totalMatterialAmount + amount.round(2)
				unless isCreate
					@taxVal[@indexKey].store 'project_name', @matterialVal["#{pid}"]["projectName"]
					@taxVal[@indexKey].store 'product_id', pid
					@taxVal[@indexKey].store 'name', desc
					@taxVal[@indexKey].store 'rate', rate
					@taxVal[@indexKey].store 'project_id', projectId
					@taxVal[@indexKey].store 'currency', curr
					@taxVal[@indexKey].store 'amount', amount
					@indexKey = @indexKey + 1
				end
				updateInvoiceItem(taxinvItem, projectId, desc, rate, nil, curr, 't', amount, nil, nil, pid) if isCreate
			end
		end
	end
	
end
