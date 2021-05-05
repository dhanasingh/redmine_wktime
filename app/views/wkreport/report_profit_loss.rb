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
end