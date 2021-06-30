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

	def calcReportData(userId, groupId, projId, from, to)
		sqlStr = " select p.name as product_name, b.name as brand_name, m.name as product_model_name, a.name as attribute_name, inv.stock_value, inv.stock_quantity, um.short_desc, projects.name as project_name, inv.currency 
					from wk_product_items pitm
					inner join (select product_item_id, product_attribute_id, uom_id, project_id, currency, sum((cost_price * available_quantity) + over_head_price) as stock_value, sum(available_quantity) as stock_quantity 
					from wk_inventory_items where product_type='I' group by product_item_id, product_attribute_id, uom_id, project_id, currency) inv on (inv.product_item_id = pitm.id) 
					left join wk_products p on (p.id = pitm.product_id)
					left join wk_product_models m on (m.id = pitm.product_model_id)
					left join wk_brands b on (b.id = pitm.brand_id)
					left join wk_product_attributes a on (a.id = inv.product_attribute_id)
					left join wk_mesure_units um on (um.id = inv.uom_id)
					left join projects on (projects.id = inv.project_id)"

		if projId.to_i > 0
			sqlStr = sqlStr + "where inv.project_id = #{projId} "
		end
		totalStockVal = 0
		entries = WkInventoryItem.find_by_sql(sqlStr)
		entries.each{ |entry| totalStockVal += entry.stock_value }
		stock = {stockEntries: entries, totalStockVal: totalStockVal}
		stock
	end
end