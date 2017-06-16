module WkpaymentHelper
include WkcrmHelper
include WktimeHelper
include WkcrmenumerationHelper
include WkbillingHelper

	
	def isCreditIssued(paymentItemId)
		creditIssued = false
		issuedCrCount = WkInvoiceItem.where(:credit_payment_item_id => paymentItemId).count
		creditIssued = true if issuedCrCount>0
		creditIssued
	end
end
