# ERPmine - ERP for service industry
# Copyright (C) 2011-2018  Adhi software pvt ltd
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
module WkshipmentHelper
  include WktimeHelper
  include WkcrmHelper
	
	def product_item_select(sqlCond, needBlank, selectedVal)
		ddArray = getProductItemArr(sqlCond, needBlank)		
		options_for_select(ddArray, :selected => selectedVal)
	end
	
	def getProductItemArr(sqlCond, needBlank)
		ddArray = Array.new
		if sqlCond.blank?
			ddValues = WkProductItem.includes(:brand, :product_model).all 
		else
			ddValues = WkProductItem.where("#{sqlCond}")
		end
		unless ddValues.blank?
			ddArray = ddValues.collect {|t| [(t.brand.blank? ? '' : t.brand.name.to_s) + ' - ' + (t.product_model.blank? ? '' : t.product_model.name.to_s) , t.id] }
		end
		ddArray.unshift(["",""]) if needBlank
		ddArray
	end
	
	def isUsedInventoryItem(invenItem)
		ret = false
		unless invenItem.blank?
			if invenItem.available_quantity != invenItem.total_quantity
				ret = true
			end
			if invenItem.depreciations.count > 0
				ret = true
			end
		end
		ret
	end
	
	def postShipmentAccounting(shipment, assetAccountingHash, assetTotal)
		if !shipment.id.blank? && autoPostGL('inventory') && getSettingCfId("inventory_cr_ledger")>0 && getSettingCfId("inventory_db_ledger") > 0
			totalAmount = shipment.inventory_items.shipment_item.sum('total_quantity*(cost_price+over_head_price)')
			# below query for Asset Parent id logic
			# totalAmount = @shipment.inventory_items.where("(product_type = 'A' and parent_id is not null) OR product_type <> 'A'").sum('total_quantity*(cost_price+over_head_price)')
			#moduleAmtHash = {'inventory' => [totalAmount.round, totalAmount.round]}
			#transAmountArr = getTransAmountArr(moduleAmtHash, nil)
			dbLedgerAmtHash = {getSettingCfId("inventory_db_ledger") => totalAmount-assetTotal}
			crLedgerAmtHash = {getSettingCfId("inventory_cr_ledger") => totalAmount}
			dbLedgerAmtHash.merge!(assetAccountingHash) { |k, o, n| o + n }
			transAmountArr = [crLedgerAmtHash, dbLedgerAmtHash]
			if totalAmount > 0 #&& autoPostGL('inventory')
				transId = shipment.gl_transaction.blank? ? nil : shipment.gl_transaction.id
				glTransaction = postToGlTransaction('inventory', transId, shipment.shipment_date, transAmountArr, shipment.inventory_items.shipment_item[0].currency, nil, nil)
				unless glTransaction.blank?
					shipment.gl_transaction_id = glTransaction.id
					shipment.save
				end				
			end
		end
	end

	def getProjects
		projects = Project.where("#{Project.table_name}.status not in(#{Project::STATUS_CLOSED},#{Project::STATUS_ARCHIVED})").order('name') 	
		projArr = options_for_wktime_project(projects, true)
		projArr
	end
end
