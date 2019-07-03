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
			'' => "",
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
	# transAmountArr[0] - crLedgerAmtHash, transAmountArr[1] - dbLedgerAmtHash
	# crLedgerAmtHash => key - leger_id, value - crAmount
	# dbLedgerAmtHash => key - leger_id, value - dbAmount
	def saveGlTransaction(transModule, id, trasdate, transType, comment, transAmountArr, currency, isDiffCur, payInvId)
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
			#orgAmount = amount
			orgCurrency = currency
			toCurrency = Setting.plugin_redmine_wktime['wktime_currency']
			exchangeRate = getExchangeRate(orgCurrency, toCurrency)
			# unless exchangeRate.blank?
				# amount = orgAmount * exchangeRate
				# currency = toCurrency
				# unless payInvId.blank?
					# payInvoice = WkInvoice.find(payInvId)
					# payInvTras = payInvoice.gl_transaction.transaction_details[0]
					# invExchangerate = payInvTras.amount/payInvTras.original_amount
					# invDayAmount = orgAmount * invExchangerate
				# end
			# end
		end
		
		unless glTransaction.valid?
			errorMsg = glTransaction.errors.full_messages.join("<br>")
		else
			glTransaction.save
			unless glTransaction.new_record?
				transDetails = glTransaction.transaction_details.destroy_all
			end
			transAmountArr.each_with_index do |amtHash, index|
				detailType = index == 0 ? 'c' :'d'
				amtHash.each do |ledgerId, amount|
					orgAmount = amount if isDiffCur
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
					# unless invExchangerate.blank? || invExchangerate != exchangeRate
						# if ledger[0] == 'c'
							# amount = orgAmount * invExchangerate
						# else
							# amount = orgAmount * exchangeRate
						# end
						# saveFluctuation(glTransaction.id, orgAmount, invExchangerate, exchangeRate)
					# end
					transDetail = saveTransDetail(ledgerId, glTransaction.id, detailType, amount, currency, orgAmount, orgCurrency)
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
	
	def getExchangedAmount(currency, amount)
		amount = amount.to_f
		toCurrency = Setting.plugin_redmine_wktime['wktime_currency']
		if currency != toCurrency
			exchangeRate = getExchangeRate(currency, toCurrency)
			unless exchangeRate.blank?
				amount = amount * exchangeRate
			end
		end
		amount.round(2)
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
	
	def getCrDbLedgerHash(transModule)
		crDbLedger = nil
		if getSettingCfId("#{transModule}_cr_ledger") > 0 && getSettingCfId("#{transModule}_db_ledger")
			crDbLedger = Hash.new
			crDbLedger['c']= getSettingCfId("#{transModule}_cr_ledger")
			crDbLedger['d']= getSettingCfId("#{transModule}_db_ledger")
		end
		crDbLedger
	end
	
	def detailsTransaction
		{
			l(:label_days) => 'days',
			l(:label_week) => 'week',
			l(:label_month) => 'month',
			l(:label_year) => 'year'
		}
	end
	
	def csv_format_conversion(transEntries)
		decimal_separator = l(:general_csv_decimal_separator)
		transactions = Array.new
		export = Redmine::Export::CSV.generate do |csv|
			# csv header fields
			if @summaryTransaction == 'days'
				headers = [
					l(:label_type),
					l(:label_date),
					l(:label_particulars),
					l(:label_debit),
					l(:label_credit)
				]
					
				crTotal = 0 
				dbTotal =0 
				openingBalance = 0
				openingBalHash = nil
				asOnDate =  nil
				asOnDate = (@from.to_date) -1 unless @from.blank?
				asOnDate = transEntries.minimum(:trans_date) - 1 unless transEntries.minimum(:trans_date).blank? #@from.blank? ?  Date.today : @from
				openingBalHash = getEachLedgerBSAmt(asOnDate, [@selectedLedger.ledger_type]) unless @ledgerId.blank? || asOnDate.blank?
				#openingBalance = openingBalHash.values[0] unless openingBalHash.blank? @selectedLedger
				transEntries.each do |entry| 
					entry_details = entry.transaction_details.includes(:ledger).order(:detail_type).pluck('wk_ledgers.id, wk_gl_transaction_details.amount, wk_gl_transaction_details.detail_type, wk_ledgers.name, wk_ledgers.ledger_type') 
					transTotal = entry_details.inject(0){|sum,x| sum + x[1] }/2
					unless @ledgerId.blank?
						#openingBalance = openingBalHash[@selectedLedger.name] unless openingBalHash.blank? || openingBalHash[@selectedLedger.name].blank?
						selectedLedgerEntries = entry.transaction_details.includes(:ledger).where(:wk_gl_transaction_details => { :ledger_id => @ledgerId }).order(:detail_type).pluck('wk_ledgers.id, wk_gl_transaction_details.amount, wk_gl_transaction_details.detail_type, wk_ledgers.name, wk_ledgers.ledger_type')
						otherDetailTypeEntries = entry.transaction_details.includes(:ledger).where.not(:wk_gl_transaction_details => { :detail_type=> selectedLedgerEntries[0][2]}).order(:detail_type).pluck('wk_ledgers.id, wk_gl_transaction_details.amount, wk_gl_transaction_details.detail_type, wk_ledgers.name, wk_ledgers.ledger_type') #:ledger_id => @ledgerId, 
						partLedgerName = otherDetailTypeEntries[0][3]
						#trAmount = selectedLedgerEntries[0][1]
					else
						detailType = 'c'
						case entry.trans_type
						when 'C'
							detailType = 'c'
						when 'P'
							detailType = 'd'
						when 'R'
							detailType = 'c'
						when 'J'
							detailType = 'd'
						end
						selectedLedgerEntries = entry.transaction_details.includes(:ledger).where(:wk_gl_transaction_details => { :detail_type => detailType }).order(:detail_type).pluck('wk_ledgers.id, wk_gl_transaction_details.amount, wk_gl_transaction_details.detail_type, wk_ledgers.name, wk_ledgers.ledger_type')
						otherDetailTypeEntries = entry.transaction_details.includes(:ledger).where.not(:wk_gl_transaction_details => { :detail_type => detailType }).order(:detail_type).pluck('wk_ledgers.id, wk_gl_transaction_details.amount, wk_gl_transaction_details.detail_type, wk_ledgers.name, wk_ledgers.ledger_type')
						partLedgerName = selectedLedgerEntries[0][3]
						#trAmount = selectedLedgerEntries[0][1]
					end
					dbAmount = nil
					crAmount = nil
					selectedLedgerEntries.each do |trans|
						 unless trans[1].blank? 
							if trans[2] == 'c' #selectedLedgerEntries[0][2]
								crAmount = crAmount.blank? ? trans[1] : crAmount + trans[1]
								crTotal = crTotal + trans[1]
							else
								dbAmount = dbAmount.blank? ? trans[1] : dbAmount + trans[1]
								dbTotal = dbTotal + trans[1]
							end
						end
					end

					transactions << [transTypeHash[entry.trans_type], entry.trans_date, partLedgerName, dbAmount.blank? ? "" : "%.2f" % dbAmount, crAmount.blank? ? "" : "%.2f" % crAmount]
				end
				unless @selectedLedger.blank? || (incomeLedgerTypes.include? @selectedLedger.ledger_type) || (expenseLedgerTypes.include? @selectedLedger.ledger_type)
					openingBalance = openingBalHash[@selectedLedger.name] unless openingBalHash.blank? || openingBalHash[@selectedLedger.name].blank?
					isSubCr = isSubtractCr(@selectedLedger.ledger_type)
					if isSubCr
						currentBal = dbTotal - crTotal
						#closeBal = currentBal + openingBalance
					else
						currentBal = crTotal - dbTotal
					end
					closeBal = currentBal + openingBalance

					if ((isSubCr && openingBalance > 0) || (!isSubCr && openingBalance < 0))
						transactions << ["", "", (l(:label_opening_balance) + ":"), ("%.2f" % openingBalance.abs), ""]
					else
						transactions << ["", "", (l(:label_opening_balance) + ":"), "", ("%.2f" % openingBalance.abs)]
					end
					transactions << ["", "", l(:label_current_total), "%.2f" % dbTotal, "%.2f" % crTotal]

					if ((isSubCr && closeBal > 0) || (!isSubCr && closeBal < 0))
						transactions << ["", "", l(:label_closing_balance), "%.2f" % closeBal.abs, ""]
					else
						transactions << ["", "", l(:label_closing_balance), "", "%.2f" % closeBal.abs]
					end
				end
			else
				headers = [
					l(:label_date_range),
					l(:label_debit),
					l(:label_credit),
					l(:label_closing_balance)
				]
				openingBalHash = getEachLedgerBSAmt(@transDate, [@selectedLedger.ledger_type]) unless @ledgerId.blank? || @transDate.blank?
				unless @selectedLedger.blank? || (incomeLedgerTypes.include? @selectedLedger.ledger_type) || (expenseLedgerTypes.include? @selectedLedger.ledger_type)
						openingBalance = openingBalHash[@selectedLedger.name] unless openingBalHash.blank? || openingBalHash[@selectedLedger.name].blank?
						isSubCr = isSubtractCr(@selectedLedger.ledger_type)
				end
				openingBal = openingBalance.nil? ? 0 : "%.2f" % openingBalance.abs
				openBalType = (isSubCr && openingBalance > 0) || (!isSubCr && openingBalance < 0) ? 'dr' : 'cr' unless openingBalance.nil?
				csv << [l(:label_opening_balance), openingBal, openBalType, ""].collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, l(:general_csv_encoding))}
				
				debitTotal = 0
				creditTotal = 0
				closeBal = 0
				@summaryHash.each do |key, value|
					debitTotal += value[:DT].to_f unless value[:DT].blank?
					creditTotal += value[:CT].to_f unless value[:CT].blank?
					diff = isSubCr ? (value[:DT].to_f - value[:CT].to_f) : (value[:CT].to_f - value[:DT].to_f)
					closeBal = (key == @summaryHash.keys.first) ? (diff + openingBalance.to_f) : (diff + closeBal)
					dateRange = key.dup
					transactions << [dateRange, value[:DT], value[:CT], closeBal.abs]
				end
				if !@summaryHash.blank?
					transactions << [l(:label_total), debitTotal, creditTotal, closeBal.abs]
				end
      		end
			csv << headers.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, l(:general_csv_encoding))}
			transactions.each do |transaction|
        		csv << transaction.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, l(:general_csv_encoding))}
			end
		end
		export
	end
end
