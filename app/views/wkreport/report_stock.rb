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

module ReportStock
  include WkreportHelper

	def calcReportData(userId, groupId, projId, from, to)
		sqlStr = " select p.name as product_name, b.name as brand_name, m.name as product_model_name, a.name as attribute_name, inv.stock_value, inv.stock_quantity, um.short_desc, projects.name as project_name, inv.currency
					from wk_product_items pitm
					inner join (select product_item_id, product_attribute_id, uom_id, project_id, currency, sum((cost_price * available_quantity) + over_head_price) as stock_value, sum(available_quantity) as stock_quantity
					from wk_inventory_items where product_type='I'"+get_comp_cond('wk_inventory_items')+" group by product_item_id, product_attribute_id, uom_id, project_id, currency
          ) inv on (inv.product_item_id = pitm.id)
					left join wk_products p on (p.id = pitm.product_id) "+get_comp_cond('p')+"
					left join wk_product_models m on (m.id = pitm.product_model_id)"+get_comp_cond('m')+"
					left join wk_brands b on (b.id = pitm.brand_id)"+get_comp_cond('b')+"
					left join wk_product_attributes a on (a.id = inv.product_attribute_id)"+get_comp_cond('a')+"
					left join wk_mesure_units um on (um.id = inv.uom_id)"+get_comp_cond('um')+"
					left join projects on (projects.id = inv.project_id)"+get_comp_cond('projects')

		if projId.to_i > 0
			sqlStr = sqlStr + "where inv.project_id = #{projId} "
		end
		totalStockVal = 0
		entries = WkInventoryItem.find_by_sql(sqlStr)
		entries.each{ |entry| totalStockVal += entry.stock_value ? entry.stock_value.to_f.round(2) : 0 }
		stock = {stockEntries: entries, totalStockVal: totalStockVal.to_f.round(2)}
		stock
	end

	def getExportData(user_id, group_id, projId, from, to)
    data = {headers: {}, data: []}
    reportData = calcReportData(user_id, group_id, projId, from, to)
    data[:headers] = {project: l(:label_project), inventory_item_id: l(:label_product), brand: l(:label_brand), model: l(:label_model), attribute: l(:label_attribute), quantity: l(:field_quantity), uom: l(:label_uom), currency: l(:field_currency), stock_value: l(:label_stock_value)}
    reportData[:stockEntries].each do |entry|
      data[:data] << {project: entry.project_name, inventory_item_id: entry.product_name, brand: entry.brand_name, model: entry.product_model_name, attribute: entry.attribute_name, quantity: entry.stock_quantity, uom: entry.short_desc, currency: entry.currency, stock_value: entry.stock_value ? entry.stock_value.to_f.round(2) : 0 }
    end
    data[:data] << {project: '', inventory_item_id: '', brand: '', model: '', attribute: '',  quantity: '', uom: '', currency: '', stock_value: reportData[:totalStockVal]}
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
    pdf.RDMMultiCell(table_width, 5, l(:report_stock), 0, 'C')
		logo =data[:logo]
		if logo.present?
			pdf.Image(logo.diskfile.to_s, page_width-50, 15, 30, 25)
		end
		pdf.ln(14)
    pdf.SetFontStyle('B', 8)
    pdf.set_fill_color(230, 230, 230)
    data[:headers].each{ |key, value| pdf.RDMCell(width, row_Height, value.to_s, 1, 0, 'C', 1) }
    pdf.ln
    pdf.set_fill_color(255, 255, 255)

    pdf.SetFontStyle('', 8)
    data[:data].each do |entry|
      entry.each{ |key, value|
        pdf.SetFontStyle('B', 8) if entry == data[:data].last
        pdf.RDMCell(width, row_Height, value.to_s, 1, 0, 'C', 1)
      }
      pdf.ln
    end
    pdf.Output
  end
end