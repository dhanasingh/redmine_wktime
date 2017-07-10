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
	
	# payInvId - Currently not in use. It is useful to calculate flactuation.
	def saveGlTransaction(transModule, id, trasdate, transType, comment, amount, currency, isDiffCur, payInvId)
		glTransaction = nil
		orgAmount = nil
		orgCurrency = nil
		#fluctuation = nil
		#invExchangerate = nil
		exchangeRate = nil
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
			toCurrency = Setting.plugin_redmine_wktime['wktime_currency']
			exchangeRate = getExchangeRate(orgCurrency, toCurrency)
			unless exchangeRate.blank?
				amount = orgAmount * exchangeRate
				currency = toCurrency
				# unless payInvId.blank?
					# payInvoice = WkInvoice.find(payInvId)
					# payInvTras = payInvoice.gl_transaction.transaction_details[0]
					# invExchangerate = payInvTras.amount/payInvTras.original_amount
					# invDayAmount = orgAmount * invExchangerate
				# end
			end
		end
		
		unless glTransaction.valid?
			errorMsg = glTransaction.errors.full_messages.join("<br>")
		else
			if glTransaction.new_record?
				glTransaction.save
				getCrDbLedgerHash(transModule).each do |ledger|
					# unless invExchangerate.blank? || invExchangerate != exchangeRate
						# if ledger[0] == 'c'
							# amount = orgAmount * invExchangerate
						# else
							# amount = orgAmount * exchangeRate
						# end
						# saveFluctuation(glTransaction.id, orgAmount, invExchangerate, exchangeRate)
					# end
					transDetail = saveTransDetail(ledger[1], glTransaction.id, ledger[0], amount, currency, orgAmount, orgCurrency)
				end
			else
				glTransaction.save
				transDetails = glTransaction.transaction_details.where(:ledger_id => [getSettingCfId("#{transModule}_cr_ledger"), getSettingCfId("#{transModule}_db_ledger")])
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
	
	def getExchangeRate(fromCurency, toCurrency)
		exchangeRate = nil
		exchange = WkExCurrencyRate.where("(from_c = '#{fromCurency}' and  to_c = '#{toCurrency}') or (from_c = '#{toCurrency}' and  to_c = '#{fromCurency}')" )
		unless exchange[0].blank?
			if exchange[0].from_c == fromCurency
				exchangeRate = exchange[0].ex_rate
			else
				exchangeRate = 1.0/exchange[0].ex_rate
			end
		end
		exchangeRate
	end
	
	# def saveFluctuation(transId, orgAmount, invExchangerate, exchangeRate)
		# fluctuation = (orgAmount*exchangeRate)- (orgAmount*invExchangerate)
		# transType = 'c'
		# transType = 'd' if fluctuation < 0
		# fluctLedgerId = getSettingCfId("payment_fluctuation_ledger")
		# transDetail = saveTransDetail(fluctLedgerId, transId, transType, fluctuation.abs, Setting.plugin_redmine_wktime['wktime_currency'], nil, nil)
	# end
	
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
	
	def getCrDbLedgerHash(transModule)
		crDbLedger = nil
		if getSettingCfId("#{transModule}_cr_ledger") > 0 && getSettingCfId("#{transModule}_db_ledger")
			crDbLedger = Hash.new
			crDbLedger['c']= getSettingCfId("#{transModule}_cr_ledger")
			crDbLedger['d']= getSettingCfId("#{transModule}_db_ledger")
		end
		crDbLedger
	end
end
