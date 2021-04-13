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

module ReportBalanceSheet
	include WkaccountingHelper

	def calcReportData(userId, groupId, projId, from, to)
		from = from.to_date
		to = to.to_date
		mainEntriesHash = Hash.new
		subEntriesHash = Hash.new
		mainTotalHash = Hash.new
		ledgerArr = ['C', 'L', 'CL', 'SP', 'PL', 'FA', 'CA']
		ledgerArr.each do |type|
			mainEntriesHash[type] = getEachLedgerBSAmt(to, [type])
			subEntriesHash[type] = getSubEntries(from, to, type)
			if type == 'PL'
				defLedgerEnries = getEachLedgerSumAmt(from, to, ['SY'])
				unless defLedgerEnries.blank?
					tempEnries = Hash.new
					tempEnries[l(:label_less_transferred)] = defLedgerEnries.values[0]
					subEntriesHash[type] = subEntriesHash[type].merge(tempEnries)
				end
				mainEntriesHash[type] = subEntriesHash[type]
				subEntriesHash[type] = nil
			end
			mainTotalHash[type] = mainEntriesHash[type].blank? ? 0 : mainEntriesHash[type].values.inject(:+)
			unless subEntriesHash[type].blank?
				mainTotalHash[type] = getEntriesTotal(subEntriesHash[type]) + mainTotalHash[type]
			end
		end
		data = {mainEntriesHash: mainEntriesHash, subEntriesHash: subEntriesHash, mainTotalHash: mainTotalHash, ledgerArr: ledgerArr, ledgerType: getLedgerTypeHash, to: to.to_formatted_s(:long)}
		data
	end
end