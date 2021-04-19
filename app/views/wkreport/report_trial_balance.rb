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

module ReportTrialBalance
	include WkaccountingHelper

	def calcReportData(userId, groupId, projId, from, to)
		from = from.to_date
		to = to.to_date
		mainEntriesHash = Hash.new
		subEntriesHash = Hash.new
		creditDebitTotalHash = Hash.new
		ledgerArr = ['C', 'L', 'CL', 'SP', 'DI', 'DE', 'II', 'IE', 'SA', 'PA', 'FA', 'CA']
		ledgerArr.each do |type|
			mainEntriesHash[type] = getEachLedgerCDAmt(from, to, type)
			subEntriesHash[type] = getTBSubEntries(from, to, type)
			creditDebitTotalHash[type] = getCreditDebitTotal(mainEntriesHash[type], subEntriesHash[type])
		end
		mainEntriesHash['PL'] = getSubEntries(from, to, 'PL')
		defLedgerEnries = getEachLedgerSumAmt(from, to, ['SY'])
		profitLossHash = mainEntriesHash['PL']['Opening Balance'].to_f + defLedgerEnries.values[0].to_f
		data = {mainEntriesHash: mainEntriesHash, subEntriesHash: subEntriesHash, creditDebitTotalHash: creditDebitTotalHash, ledgerArr: ledgerArr, ledgerType: getLedgerTypeHash, to: to.to_formatted_s(:long),
			 profitLossHash: profitLossHash}
		data
	end
end