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
		headers ={ledger_group: l(:label_particulars), ledger: '', value: '', total: rptData[:from] + l(:label_date_to) + rptData[:to]}
		data << {ledger_group: l(:label_trading_account) + ':', ledger: '', value: '', total: ''}
		rptData[:incomeLedger].slice(0, 2).each do |type|
			data << {ledger_group: rptData[:ledgerType][type], ledger: '', value: '', total: rptData[:totalHash][type]&.round(2)}
			if rptData[:totalHash][type] != 0
				renderLedgerVal(data, rptData[:entriesHash][type])
			end
		end
		data << {ledger_group: l(:label_cost_of_sales), ledger: '', value: '', total: rptData[:costOfSale]&.round(2)}
		rptData[:expenseLedger].slice(0, 2).each do |type|
			data << {ledger_group: rptData[:ledgerType][type], ledger: '', value: rptData[:totalHash][type]&.round(2), total: ''}
			if rptData[:totalHash][type] != 0
				renderLedgerVal(data, rptData[:entriesHash][type])
			end
		end
		data << {ledger_group: l(:label_gross) + " " + l(:label_profit), ledger: '', value: '', total: rptData[:grossProfit]&.round(2)}
		data << {ledger_group: l(:label_income) + " " + l(:label_statement) + ':', ledger: '', value: '', total: ''}
		['II', 'IE'].each do |type|
			data << {ledger_group: rptData[:ledgerType][type], ledger: '', value: '', total: rptData[:totalHash][type]&.round(2)}
			if rptData[:totalHash][type] != 0
				renderLedgerVal(data, rptData[:entriesHash][type])
			end
			if type == 'II'
				data << {ledger_group: '', ledger: '', value: '', total: rptData[:income]&.round(2)}
			end
		end
		data << {ledger_group: l(:label_net) + " " + l(:label_profit), ledger: '', value: '', total: rptData[:netProfit]&.round(2)}
		return {data: data, headers: headers}
	end

	def renderLedgerVal(data, entries)
		entries.each_with_index do |row_col,index|
			data << {ledger_group: '', ledger: row_col[0], value: row_col[1], total: ''} unless row_col[1] == 0
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
		pdf.RDMMultiCell(table_width, row_Height, l(:report_profit_loss), 0, 'C')
		pdf.RDMMultiCell(table_width, row_Height, data[:from].to_formatted_s(:long) + " " + l(:label_date_to) + " " + data[:to].to_formatted_s(:long), 0, 'C')
		pdf.SetFontStyle('B', 9)
		pdf.set_fill_color(230, 230, 230)
		data[:headers].each{ |key, value| pdf.RDMCell(width, row_Height, value.to_s, 0, 0, '', 1) }
		pdf.ln
		pdf.set_fill_color(255, 255, 255)

		pdf.SetFontStyle('', 8)
		data[:data].each do |entry|
			entry.each do |key, value|
				[:ledger_group].include?(key) ? pdf.SetFontStyle('B',9)  : pdf.SetFontStyle('',8) 
        pdf.RDMCell(width, row_Height, value.to_s, 0, 0, '', 0)
      end
			pdf.ln
		end
		pdf.Output
	end
end