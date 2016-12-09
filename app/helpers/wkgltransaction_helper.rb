module WkgltransactionHelper

include WktimeHelper
include WkaccountingHelper

	def transTypeHash
		txnType = {
			'C' => l(:label_txn_contra),
			'P' => l(:label_txn_payment),
			'R' =>  l(:label_txn_receipt),
			'J' => l(:label_txn_journal),
			'S' => l(:label_txn_sales),
			'CN' => l(:label_txn_credit_note),
			'PR' => l(:label_txn_purchase),
			'DN' => l(:label_txn_debit_note)
		}
		txnType	
	end
	
	def saveGlTransaction(id, trasdate, transType, comment, amount, currency, isDiffCur)
		glTransaction = nil
		orgAmount = nil
		orgCurrency = nil
		unless id.blank?
			glTransaction = WkGlTransaction.find(id)
		else
			glTransaction = WkGlTransaction.new
		end
		glTransaction.trans_type = transType
		glTransaction.trans_date = trasdate
		glTransaction.comment = comment
		
		if isDiffCur
			orgAmount = amount
			orgCurrency = currency
		end
		
		unless glTransaction.valid?
			errorMsg = glTransaction.errors.full_messages.join("<br>")
		else
			if glTransaction.new_record?
				glTransaction.save
				getCrDbLedgerHash.each do |ledger|
					transDetail = saveTransDetail(ledger[1], glTransaction.id, ledger[0], amount, currency, orgAmount, orgCurrency)
				end
			else
				transDetails = glTransaction.transaction_details.where(:ledger_id => [getSettingCfId('invoice_cr_ledger'), getSettingCfId('invoice_db_ledger')])
				allowCr = true
				allowDb = true
				transDetails.each do |detail|
					unless detail.detail_type == 'c' && allowCr || detail.detail_type == 'd' && allowDb
						detail.destroy
						next
					else
						if detail.detail_type == 'c'
							allowCr = false
						else
							allowDb = false
						end
					end
					detail.amount = amount
					detail.currency = currency
					detail.original_amount = orgAmount
					detail.original_currency = orgCurrency
					detail.save
				end
			end
		end
		glTransaction
	end
	
	def saveTransDetail(ledgerId, transId, detailType, amount, currency, orgAmount, orgCurrency)
		transDetail = WkGlTransactionDetail.new
		transDetail.ledger_id = ledgerId
		transDetail.gl_transaction_id = transId
		transDetail.detail_type = detailType
		transDetail.amount = amount
		transDetail.currency = currency
		transDetail.original_amount = orgAmount
		transDetail.original_currency = orgCurrency
		transDetail.save
		transDetail
	end
	
	def getCrDbLedgerHash
		crDbLedger = nil
		if getSettingCfId('invoice_cr_ledger') > 0 && getSettingCfId('invoice_db_ledger')
			crDbLedger = Hash.new
			crDbLedger['c']= getSettingCfId('invoice_cr_ledger')
			crDbLedger['d']= getSettingCfId('invoice_db_ledger')
		end
		crDbLedger
	end
end
