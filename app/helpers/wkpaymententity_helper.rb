module WkpaymententityHelper
include WkinvoiceHelper
include WkcrmHelper
include WktimeHelper
include WkcrmenumerationHelper
include WkbillingHelper


	def options_for_parent_select(value)
		options_for_select([[l(:label_account), 'WkAccount'],
							[l(:label_contact), 'WkCrmContact']],
							value.blank? ? 'WkAccount' : value)
	end
	
	def updatePaymentItem(payItem, paymentId, invoiceId, orgAmount, orgCurrency) # transId

		toCurrency = Setting.plugin_redmine_wktime['wktime_currency']
		amount = getExchangedAmount(orgCurrency, orgAmount)
		payItem.payment_id = paymentId
		payItem.invoice_id = invoiceId
		payItem.is_deleted = false
		payItem.currency = toCurrency
		payItem.amount = amount
		payItem.original_amount = orgAmount
		payItem.original_currency = orgCurrency
		payItem.modified_by_user_id = User.current.id
		if payItem.new_record?
			payItem.created_by_user_id = User.current.id
		end
		payItem.save()
		payItem
	end
	
	def isCreditIssued(paymentItemId)
		creditIssued = false
		issuedCrCount = WkInvoiceItem.where(:credit_payment_item_id => paymentItemId).count
		creditIssued = true if issuedCrCount>0
		creditIssued
	end
	
end
