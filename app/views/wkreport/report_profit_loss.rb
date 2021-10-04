# ERPmine - ERP for service industry
# Copyright (C) 2011-2021 Adhi software pvt ltd
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

module ReportProfitLoss
	include WkaccountingHelper
  include WkreportHelper

	def calcReportData(userId, groupId, projId, from, to)
		from = from.to_date
		to = to.to_date
		entriesHash = Hash.new
		totalHash = Hash.new
		plLedgerTypes = incomeLedgerTypes + expenseLedgerTypes
		plLedgerTypes.each do |type|
			entriesHash[type] = getEachLedgerSumAmt(from, to, [type])
			totalHash[type] = entriesHash[type].blank? ? 0 : entriesHash[type].values.inject(:+)
		end
		grossProfit = totalHash['DI'] + totalHash['SA'] - totalHash['DE'] - totalHash['PA']
		netProfit = grossProfit + totalHash['II'] - totalHash['IE']
		income = grossProfit + totalHash['II']
		costOfSale = totalHash['DE'] + totalHash['PA']
		data = {entriesHash: entriesHash, totalHash: totalHash, incomeLedger: incomeLedgerTypes, expenseLedger: expenseLedgerTypes, ledgerType: getLedgerTypeHash,
			from: from.to_formatted_s(:long), to: to.to_formatted_s(:long), grossProfit: grossProfit, netProfit: netProfit, income: income, costOfSale: costOfSale}
		data
	end

	def getExportData(user_id, group_id, projId, from, to)
    rptData = calcReportData(user_id, group_id, projId, from, to)
    headers = {}
    data = []
		headers ={particulars: l(:label_particulars), ledger: rptData[:from], value: l(:label_date_to), total: rptData[:to]}
		data << {particulars: l(:label_trading_account) + ':', ledger: '', value: '', total: ''}
		rptData[:incomeLedger].slice(0, 2).each do |type|
			data << {particulars: rptData[:ledgerType][type], ledger: '', value: '', total: rptData[:totalHash][type]&.round(2)}
			if rptData[:totalHash][type] != 0
				renderLedgerVal(data, rptData[:entriesHash][type])
			end
		end
		data << {particulars: l(:label_cost_of_sales), ledger: '', value: '', total: rptData[:costOfSale]&.round(2)}
		rptData[:expenseLedger].slice(0, 2).each do |type|
			data << {particulars: rptData[:ledgerType][type], ledger: '', value: rptData[:totalHash][type]&.round(2), total: ''}
			if rptData[:totalHash][type] != 0
				renderLedgerVal(data, rptData[:entriesHash][type])
			end
		end
		data << {particulars: l(:label_gross) + " " + l(:label_profit), ledger: '', value: '', total: rptData[:grossProfit]&.round(2)}
		data << {particulars: l(:label_income) + " " + l(:label_statement) + ':', ledger: '', value: '', total: ''}
		['II', 'IE'].each do |type|
			data << {particulars: rptData[:ledgerType][type], ledger: '', value: '', total: rptData[:totalHash][type]&.round(2)}
			if rptData[:totalHash][type] != 0
				renderLedgerVal(data, rptData[:entriesHash][type])
			end
			if type == 'II'
				data << {particulars: '', ledger: '', value: '', total: rptData[:income]&.round(2)}
			end
		end
		data << {particulars: l(:label_net) + " " + l(:label_profit), ledger: '', value: '', total: rptData[:netProfit]&.round(2)}
		return {data: data, headers: headers}
	end

	def renderLedgerVal(data, entries)
		entries.each_with_index do |row_col,index|
			data << {particulars: '', ledger: row_col[0], value: row_col[1], total: ''} unless row_col[1] == 0
		end
		data
	end
end