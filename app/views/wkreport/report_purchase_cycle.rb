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

module ReportPurchaseCycle
	include WktimeHelper
  include WkreportHelper

	def calcReportData(userId, groupId, projId, from, to)
		sqlStr =  "select rfq.id as rfq_id, rfq.name as rfq_name, rfq.start_date as rfq_start, rq.quote_id," +
		" q.invoice_date as quote_date, rq.won_date, poq.purchase_order_id, po.invoice_date po_date," +
		" sipo.supplier_inv_id, si.invoice_date as si_date, CASE WHEN pay.paid_amount >= inv.invoice_amount THEN pay.payment_date ELSE null END as payment_date from wk_rfqs rfq" +
		" left join wk_rfq_quotes rq on (rq.rfq_id = rfq.id and rq.is_won = #{booleanFormat(true)})" + get_comp_cond('rq')+
		" left join wk_invoices q on  (q.id = rq.quote_id)" + get_comp_cond('q')+
		" left join wk_po_quotes poq on (rq.quote_id = poq.quote_id)" +get_comp_cond('poq')+
		" left join wk_invoices po on (po.id = poq.purchase_order_id)" +get_comp_cond('po')+
		" left join wk_po_supplier_invoices sipo on (sipo.purchase_order_id = poq.purchase_order_id)" +get_comp_cond('sipo')+
		" left join wk_invoices si on (si.id = sipo.supplier_inv_id)" +get_comp_cond('si')+
		" left join (select sum(pmi.amount) as paid_amount, i.id as invoice_id," +
		" max(p.payment_date) as payment_date from wk_invoices i" +
		" inner join wk_payment_items pmi on(i.id=pmi.invoice_id and pmi.is_deleted= #{booleanFormat(false)}" +get_comp_cond('pmi')+")"+
		" left join wk_payments p on(pmi.payment_id = p.id ) "+get_comp_cond('p')+get_comp_cond('i',"where")+" group by i.id  ) pay  on (pay.invoice_id = si.id )" +
		" left join (select i.invoice_date, sum(ii.amount) as invoice_amount," +
		" i.id as invoice_id from wk_invoices i left join wk_invoice_items ii on(i.id=ii.invoice_id
		"+get_comp_cond('ii')+")" + get_comp_cond('i',"where")+
		" group by i.id, i.invoice_date) inv on (inv.invoice_id = si.id)" +
		" where rfq.start_date between '#{from}' and '#{to}'"+ get_comp_cond('rfq')
		cycleEntries = WkRfq.find_by_sql(sqlStr)
		wqTotal = wqCount = poTotal = poCount = siTotal = siCount = payTotal = payCount =  0
		purchaseData = {}
		cycleEntries.each_with_index do |entry, index|
			purchaseData[index] = {}
			purchaseData[index]['name'] = entry.rfq_name
			purchaseData[index]['wqCycle'] = purchaseData[index]['poCycle'] = purchaseData[index]['siCycle'] = purchaseData[index]['payCycle'] = nil
			unless entry.won_date.blank? || entry.quote_date.blank?
				purchaseData[index]['wqCycle'] = (entry.won_date - entry.quote_date).to_f
				wqTotal = wqTotal + purchaseData[index]['wqCycle']
				wqCount = wqCount + 1
			end

			unless entry.won_date.blank? || entry.po_date.blank?
				purchaseData[index]['poCycle'] = (entry.po_date - entry.won_date).to_f
				poTotal = poTotal + purchaseData[index]['poCycle']
				poCount = poCount + 1
			end

			unless entry.po_date.blank? || entry.si_date.blank?
				purchaseData[index]['siCycle'] = (entry.si_date - entry.po_date).to_f
				siTotal = siTotal + purchaseData[index]['siCycle']
				siCount = siCount + 1
			end

			unless entry.payment_date.blank? || entry.si_date.blank?
				purchaseData[index]['payCycle'] = (entry.payment_date - entry.si_date).to_f
				payTotal = payTotal + purchaseData[index]['payCycle']
				payCount = payCount + 1
			end
		end
		wqTotal = (wqTotal/wqCount).round(2) if wqTotal > 0
		poTotal = (poTotal/poCount).round(2) if poTotal > 0
		siTotal = (siTotal/siCount).round(2) if siTotal > 0
		payTotal = (payTotal/payCount).round(2) if payCount > 0
		purchase = {purchaseData: purchaseData, wqTotal: wqTotal, poTotal: poTotal, siTotal: siTotal, payTotal: payTotal, from: from.to_formatted_s(:long), to: to.to_formatted_s(:long)}
		purchase
	end

	def getExportData(user_id, group_id, projId, from, to)
		data = {headers: {}, data: []}
		reportData = calcReportData(user_id, group_id, projId, from, to)
		data[:headers] = {rfq: l(:label_rfq), purchase_cycle: l(:report_purchase_cycle)+''+ l(:label_in_days), poCycle: '', siCycle: '', payCycle:''}
		data[:data] << {rfq: '', winning_quote: l(:label_winning_quote), purchase_order: l(:label_purchase_order), supplier_invoice: l(:label_supplier_invoice), supplier_payment: l(:label_supplier_payment)}
		reportData[:purchaseData].each do |index, entry|
			data[:data] << {name: entry['name'],wqCycle: entry['wqCycle'],poCycle: entry['poCycle'],siCycle: entry['siCycle'],payCycle: entry['payCycle']}
		end
		data[:data] << {average: l(:label_average),wqCycle: reportData[:wqTotal],poCycle: reportData[:poTotal],siCycle: reportData[:siTotal],payCycle: reportData[:payTotal]}
		data
	end


	def pdf_export(data)
    pdf = ITCPDF.new(current_language,'L')
    pdf.add_page
    row_Height = 8
    page_width    = pdf.get_page_width
    left_margin   = pdf.get_original_margins['left']
    right_margin  = pdf.get_original_margins['right']
    table_width = page_width - right_margin - left_margin
    width = table_width/data[:headers].length

    pdf.SetFontStyle('B', 13)
    pdf.RDMMultiCell(table_width, 5, data[:location], 0, 'C')
    pdf.RDMMultiCell(table_width, 5, l(:report_purchase_cycle) + " " + l(:label_report), 0, 'C')
    pdf.RDMMultiCell(table_width, 5, data[:from].to_s+" "+ l(:label_date_to) +" "+data[:to].to_s, 0, 'C')

		logo =data[:logo]
		if logo.present?
			pdf.Image(logo.diskfile.to_s, page_width-50, 15, 30, 25)
		end
		pdf.ln(10)
    pdf.SetFontStyle('B', 8)
    pdf.set_fill_color(230, 230, 230)
    data[:headers].each{ |key, value|
			pdf.RDMCell(width, row_Height, value.to_s, 1, 0, 'C', 1)
		}
    pdf.ln
    pdf.set_fill_color(255, 255, 255)

    pdf.SetFontStyle('', 8)
    data[:data].each do |entry|
			entry.each{ |key, value|
				border = 0
				pdf.SetFontStyle('B', 8) if entry == data[:data].last
				pdf.RDMCell(width, row_Height, value.to_s, 1, 0, 'C', 1)
			}
    	pdf.ln
    end
    pdf.Output
  end
end