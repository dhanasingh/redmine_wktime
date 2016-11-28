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
			"SH" => l(:label_stock_in_hand),
			"SC" => l(:label_sundry_creditors),
			"SD" => l(:label_sundry_debtors),
			"SP" => l(:label_suspense_ac),
			"UL" => l(:label_unsecured_loans)
			}
		ledgerType
	end
	
	def getTransDetails(from, to)
		WkTransactionDetail.includes(:ledger, :wktransaction).where('wk_transactions.trans_date between ? and ?', from, to).references(:ledger,:wktransaction)
	end
	
	def getEachLedgerSumAmt(from, to, ledgerType)
		if ledgerType.blank?
			WkTransactionDetail.includes(:ledger, :wktransaction).where('wk_transactions.trans_date between ? and ?', from, to).references(:ledger,:wktransaction).group('wk_ledgers.id, wk_ledgers.name').sum('wk_transaction_details.amount')
		else
			WkTransactionDetail.includes(:ledger, :wktransaction).where('wk_ledgers.ledger_type = ? and wk_transactions.trans_date between ? and ?', ledgerType, from, to).references(:ledger,:wktransaction).group('wk_ledgers.id, wk_ledgers.name').sum('wk_transaction_details.amount')
		end
	end
end
