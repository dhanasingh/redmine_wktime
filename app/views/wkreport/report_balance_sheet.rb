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
  include WkreportHelper

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

	def getExportData(user_id, group_id, projId, from, to)
    rptData = calcReportData(user_id, group_id, projId, from, to)
    headers = {}
    data = []
		headers ={ledger_group: l(:label_particulars), ledger_type: '', ledger: '', value: '', total: rptData[:to]}
		data << {ledger_group: l(:label_of_funds,l(:label_copy_source)) + ':', ledger_type: '', ledger: '', value: '', total: ''}
		renderSection(data, rptData, 0, 4)
		data << {ledger_group: l(:label_of_funds,l(:label_application)) + ':', ledger_type: '', ledger: '', value: '', total: ''}
		renderSection(data, rptData, 5, 6)
		return {data: data, headers: headers}
	end

	def renderSection(data, rptData, from, to)
		total = 0
		for i in from..to
			if rptData[:mainTotalHash][rptData[:ledgerArr][i]] != 0
				data << {ledger_group: getSectionHeader(rptData[:ledgerArr][i]), ledger_type: '', ledger: '', value: '', total: rptData[:mainTotalHash][rptData[:ledgerArr][i]]}
				unless rptData[:subEntriesHash][rptData[:ledgerArr][i]].blank?
					rptData[:subEntriesHash][rptData[:ledgerArr][i]].each do |key, subEntry|
						unless subEntry.blank? || subEntry.values.inject(:+) == 0
							data << {ledger_group: '', ledger_type: getSectionHeader(key), ledger: '', value: subEntry.values.inject(:+).round(2), total: ''}
							renderLedgerVal(data, subEntry, 'subledger')
						end
					end
				end
				renderLedgerVal(data, rptData[:mainEntriesHash][rptData[:ledgerArr][i]], 'mainledger') 
			end
			total = total + rptData[:mainTotalHash][rptData[:ledgerArr][i]]
		end
		data << {ledger_group: l(:label_total), ledger_type: '', ledger: '', value: '', total: total&.round(2)}
		data
	end

	def renderLedgerVal(data, entries, type)
		entries.each_with_index do |row_col,index|
			unless row_col[1] == 0
				data << {ledger_group: '', ledger_type: row_col[0], ledger: '', value: row_col[1], total: ''} if type == 'mainledger'
				data << {ledger_group: '', ledger_type: '', ledger: row_col[0], value: row_col[1], total: ''} if type == 'subledger'
			end
		end
		data
	end

  def pdf_export(data)
		pdf = ITCPDF.new(current_language, "L")
		pdf.add_page
		row_Height = 8
		page_width    = pdf.get_page_width
		left_margin   = pdf.get_original_margins['left']
		right_margin  = pdf.get_original_margins['right']
		table_width = page_width - right_margin - left_margin
		width = table_width/data[:headers].length
		pdf.ln
		pdf.SetFontStyle('B', 10)
		pdf.RDMMultiCell(table_width, row_Height, getMainLocation, 0, 'C')
		pdf.RDMMultiCell(table_width, row_Height, l(:report_balance_sheet), 0, 'C')
		pdf.RDMMultiCell(table_width, row_Height, l(:label_as_at) + " " + data[:to].to_formatted_s(:long), 0, 'C')
		pdf.SetFontStyle('', 8)
		data[:data].each do |entry|
			entry.each do |key, value|
				[:ledger_group, :ledger_type].include?(key) ? pdf.SetFontStyle('B',9)  : pdf.SetFontStyle('',8) 
        pdf.RDMCell(width, row_Height, value.to_s, 0, 0, '', 0)
      end
			pdf.ln
		end
		pdf.Output
	end
end