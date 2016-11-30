module WktransactionHelper

include WktimeHelper
include WkaccountingHelper

	def options_for_txn_type(value)
		options_for_select([[l(:label_txn_contra), 'Contra'],
							[l(:label_txn_payment), 'Payment'],
							[l(:label_txn_receipt), 'Receipt'],
							[l(:label_txn_journal), 'Journal'],
							[l(:label_txn_sales), 'Sales'],
							[l(:label_txn_credit_note), 'Credit_Note'],
							[l(:label_txn_purchase), 'Purchase'],
							[l(:label_txn_debit_note), 'Debit_Note']],
							value.blank? ? 'Payment' : value)		
	end

end
