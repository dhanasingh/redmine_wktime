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

module WkaccountingHelper

include WktimeHelper

	def getLedgerTypeHash
		ledgerType = {
			"BA" => l(:label_bank_ac),
			"OC" => l(:label_bank_occ_ac),
			"OD" => l(:label_bank_od_ac),
			"BR" => l(:label_branch_division),
			"C" => l(:label_capital_account),
			"CS" => l(:label_cash_in_hand),
			"CA" => l(:label_current_assets),
			"CL" => l(:label_current_liabilities),
			"DP" => l(:label_deposits),
			"DE" => l(:label_direct_expenses),
			"DI" => l(:label_direct_incomes),
			"T" => l(:label_duties_taxes),
			"FA" => l(:label_fixed_assets),
			"IE" => l(:label_indirect_expenses),
			"II" => l(:label_indirect_incomes),
			"IN" => l(:label_investments),
			"AD" => l(:label_loans_advances),
			"L" => l(:label_loans),
			"MS" => l(:label_misc_expenses),
			"PR" => l(:label_provisions),
			"PA" => l(:label_purchase_accounts),
			"RS" => l(:label_reserves_surplus),
			"RE" => l(:label_retained_earnings),
			"SA" => l(:label_sales_accounts),
			"SL" => l(:label_secured_loans),
			#"SH" => l(:label_stock_in_hand),
			"SC" => l(:label_sundry_creditors),
			"SD" => l(:label_sundry_debtors),
			"SP" => l(:label_suspense_ac),
			"UL" => l(:label_unsecured_loans)
			}
		ledgerType
	end
	
	def getSectionHeader(type)
		getLedgerTypeHash[type].blank? ? l(:report_profit_loss) : getLedgerTypeHash[type]
	end
	
	def getLedgerTypeGrpHash
		ledgerTypeGrps = {
			"CA" => ['BA', 'CS', 'DP', 'AD', 'SD', 'IN', 'MS'], #'SH',
			"L" => ['OD', 'SL', 'UL', 'OC'],
			"CL" => ['T', 'PR', 'SC'],
			"C" => ['RS', 'RE'],
			"PL" => ['DI', 'DE', 'II', 'IE', 'SA', 'PA']
		}
		ledgerTypeGrps
	end
	
	def incomeLedgerTypes
		['SA','DI','II']
	end
	
	def expenseLedgerTypes
		['PA','DE','IE']
	end
	
	def sourceOfFundLTypes
		['C', 'L', 'CL', 'SP', 'SY']
	end
	
	def appOfFundLTypes
		 ['FA', 'CA']
	end
	
	def getSubEntries(from, asOnDate, ledgerType)
		subEntriesHash = nil
		bsEndDate = ledgerType == 'PL' ? from -1  : asOnDate
		unless getLedgerTypeGrpHash[ledgerType].blank?
			subEntriesHash = Hash.new
			getLedgerTypeGrpHash[ledgerType].each do |subType|
				subEntriesHash[subType] = getEachLedgerBSAmt(bsEndDate, [subType])
			end
		end
		if ledgerType == 'PL'
			totalIncome = 0
			totalExpense = 0
			defLedger = WkLedger.where(:ledger_type => 'SY')
			incomeLedgerTypes.each do |type|
				totalIncome = totalIncome + getEntriesTotal(subEntriesHash[type])
			end
			expenseLedgerTypes.each do |type|
				totalExpense = totalExpense + getEntriesTotal(subEntriesHash[type])
			end
			subEntriesHash.clear
			subEntriesHash[l(:wk_label_opening)+ " " + l(:wk_field_balance)] = totalIncome - totalExpense + (defLedger[0].opening_balance.blank? ? 0 : defLedger[0].opening_balance)
			subEntriesHash[l(:label_current)+ " " + l(:label_period)] = getPLfor(from, asOnDate)
			
		end
		subEntriesHash
	end
	
	def getPLfor(from, to)
		totalIncome = 0
		totalExpense = 0
		incomeLedgerTypes.each do |type|
			income = getEachLedgerSumAmt(from, to, [type])
			totalIncome = totalIncome + income.values.inject(:+) unless income.blank?
		end
		
		expenseLedgerTypes.each do |type|
			expense = getEachLedgerSumAmt(from, to, [type])
			totalExpense = totalExpense + expense.values.inject(:+) unless expense.blank?
		end
		profit = totalIncome - totalExpense
		profit
	end
	
	def getEntriesTotal(entriesHash)
		total = 0
		entriesHash.each do |entry|
			unless entry[1].blank?
				if entry[1].is_a?(Hash)
					total = entry[1].values.inject(:+) + total
				else
					total = entry[1] + total
				end
			end
		end
		total
	end
	
	def getTransDetails(from, to)
		WkGlTransactionDetail.includes(:ledger, :wkgltransaction).where('wk_gl_transactions.trans_date between ? and ?', from, to).references(:ledger,:wkgltransaction)
	end
	
	def getBSProfitLoss(from, to)
		WkGlTransactionDetail.includes(:ledger, :wkgltransaction).where('wk_gl_transactions.trans_date between ? and ?', from, to).references(:ledger,:wkgltransaction)
	end
	
	def getEachLedgerBSAmt(asOnDate, ledgerType)
		typeArr = ['c', 'd']
		detailHash = Hash.new
		typeArr.each do |type|
			detailHash[type] = WkGlTransactionDetail.includes(:ledger, :wkgltransaction).where('wk_gl_transaction_details.detail_type = ? and wk_ledgers.ledger_type IN (?) and wk_gl_transactions.trans_date <= ?', type, ledgerType, asOnDate).references(:ledger,:wkgltransaction).group('wk_ledgers.id').sum('wk_gl_transaction_details.amount')
		end
		profitHash = calculateBalance(detailHash['c'], detailHash['d'], ledgerType[0])
		balHash = Hash.new
		ledgers = WkLedger.where(:ledger_type => ledgerType)
		ledgers.each do |ledger|
			unless profitHash[ledger.id].blank? && (ledger.opening_balance.blank? || ledger.opening_balance == 0)
				balHash[ledger.name] = (profitHash[ledger.id].blank? ? 0 : profitHash[ledger.id]) + ((ledger.opening_balance.blank? || ledger.ledger_type == 'SY') ? 0 : ledger.opening_balance)
			end
		end
		balHash
	end
	
	def calculateBalance(creditHash, debitHash, ledgerType)
		if isSubtractCr(ledgerType)
			creditHash = inverseHashVal(creditHash)
		else
			debitHash = inverseHashVal(debitHash)
		end
		profitHash = creditHash.merge(debitHash){|key, oldval, newval| newval + oldval}
		profitHash
	end
	
	def isSubtractCr(ledgerType)
		isSubtract = true
		subLedTypeArr = []
		sourceOfFundLTypes.each do |val|
			subLedTypeArr = subLedTypeArr + getLedgerTypeGrpHash[val] unless getLedgerTypeGrpHash[val].blank?
		end
		subLedTypeArr = sourceOfFundLTypes + subLedTypeArr
		subLedTypeArr = subLedTypeArr + incomeLedgerTypes
		if subLedTypeArr.include? ledgerType
			isSubtract = false
		end
		isSubtract
	end
	
	def inverseHashVal(sourceHash)
		targetHash = Hash.new
		sourceHash.each do |key, val|
			targetHash[key] = -1 * val
		end
		targetHash
	end
	
	def getEachLedgerSumAmt(from, to, ledgerType)
		typeArr = ['c', 'd']
		detailHash = Hash.new
		if ledgerType.blank?
			typeArr.each do |type|
				detailHash[type] = WkGlTransactionDetail.includes(:ledger, :wkgltransaction).where('wk_gl_transaction_details.detail_type = ? and wk_gl_transactions.trans_date between ? and ?', type, from, to).references(:ledger,:wkgltransaction).group('wk_ledgers.id, wk_ledgers.name').sum('wk_gl_transaction_details.amount')
			end
		else
			typeArr.each do |type|
				detailHash[type] = WkGlTransactionDetail.includes(:ledger, :wkgltransaction).where('wk_gl_transaction_details.detail_type = ? and wk_ledgers.ledger_type IN (?) and wk_gl_transactions.trans_date between ? and ?', type, ledgerType, from, to).references(:ledger,:wkgltransaction).group('wk_ledgers.id, wk_ledgers.name').sum('wk_gl_transaction_details.amount')
			end
		end
		profitHash = calculateBalance(detailHash['c'], detailHash['d'], ledgerType[0])
		profitHash
	end
	
	def getTransType(crLedgerType, dbLedgerType)
		transtype = nil
		if (crLedgerType == 'C' || crLedgerType == 'BA') && (dbLedgerType == 'C' || dbLedgerType == 'BA')
			transtype = 'C'
		elsif (dbLedgerType == 'PA')
			transtype = 'PR'
		elsif (crLedgerType == 'SA')
			transtype = 'S'
		elsif (crLedgerType == 'C' || crLedgerType == 'BA')
			transtype = 'P'
		elsif (dbLedgerType == 'C' || dbLedgerType == 'BA')
			transtype = 'R'
		else
			transtype = 'J'
		end
		transtype
	end
	
	def getEachLedgerCDAmt(asOnDate, ledgerType)
		typeArr = ['c', 'd']
		detailHash = Hash.new
		typeArr.each do |type|
			detailHash[type] = WkGlTransactionDetail.includes(:ledger, :wkgltransaction).where('wk_gl_transaction_details.detail_type = ? and wk_ledgers.ledger_type IN (?) and wk_gl_transactions.trans_date <= ?', type, ledgerType, asOnDate).references(:ledger,:wkgltransaction).group('wk_ledgers.id').sum('wk_gl_transaction_details.amount')
		end
		creditDebitHash = Hash.new
		unless detailHash.blank?
			ledgers = WkLedger.where(:ledger_type => ledgerType)
			isSubCr = isSubtractCr(ledgerType)
			ledgers.each do |ledger|
				key = ledger.name 
				creditDebitHash[key] = Hash.new if creditDebitHash[key].blank?
				if !detailHash['d'][ledger.id].blank? && !detailHash['c'][ledger.id].blank?
					creditDebitDiff = (detailHash['d'][ledger.id]) - (detailHash['c'][ledger.id])
					creditDebitHash[key]['d'] = creditDebitDiff > 0 ? creditDebitDiff.abs : nil
					creditDebitHash[key]['c'] = creditDebitDiff < 0 ? creditDebitDiff.abs : nil
				else
					creditDebitHash[key]['d'] = isSubCr ? (ledger.opening_balance == 0 ? detailHash['d'][ledger.id] : detailHash['d'][ledger.id].to_i + (ledger.opening_balance).to_i) : detailHash['d'][ledger.id]
					creditDebitHash[key]['c'] = isSubCr ? detailHash['c'][ledger.id] : (ledger.opening_balance == 0 ? detailHash['c'][ledger.id] : detailHash['c'][ledger.id].to_i + (ledger.opening_balance).to_i)
				end
			end
		end
		creditDebitHash	
	end
	
	def getTBSubEntries(asOnDate, ledgerType)
		subEntriesHash = nil
		unless getLedgerTypeGrpHash[ledgerType].blank?
			subEntriesHash = Hash.new
			getLedgerTypeGrpHash[ledgerType].each do |subType|
				subEntriesHash[subType] = getEachLedgerCDAmt(asOnDate, [subType])
			end
		end
		subEntriesHash
	end

	def getCreditDebitTotal(mainHash, subHash)
		@debitTot = 0
		@creditTot =0
		creditDebitTotHash = Hash.new
		unless mainHash.blank?
			mainHash.each do |ledger, entry|
				entry.each do |type, amount|
					if type == 'd'
						@debitTot += amount unless amount.blank?
					else
						@creditTot += amount unless amount.blank?
					end
				end 
			end
		end
		unless subHash.blank?
			subHash.each do |mainLedger, entry|
				entry.each do |subLedger, value|
					value.each do |type, amount|
						if type == 'd'
							@debitTot += amount unless amount.blank?
						else
							@creditTot += amount unless amount.blank?
						end
					end
				end 
			end
		end
		creditDebitTotHash['debit'] = @debitTot
		creditDebitTotHash['credit'] = @creditTot
		creditDebitTotHash
	end
end
