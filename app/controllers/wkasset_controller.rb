# ERPmine - ERP for service industry
# Copyright (C) 2011-2020  Adhi software pvt ltd
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
class WkassetController < WkproductitemController
  unloadable
	menu_item :wkproduct
	include WktimeHelper
	include WkassetdepreciationHelper


	def getItemType
		'A'
	end
	
	def showAssetProperties
		true
	end
	
	def getProductAsset
		assetArr = ""
		assetItems = WkInventoryItem.joins(:product_item, :asset_property).where("product_type = 'A'").select("wk_inventory_items.id, wk_asset_properties.name")
		assetItems = assetItems.where(" wk_product_items.product_id = ?", params[:id].to_i) unless params[:id].blank?
		assetItems = assetItems.where(" is_disposed != ? OR is_disposed is NULL", true) if params[:newDepr] == "true"
		
		assetItems.each do | entry |
			assetArr << entry.id.to_s() + ',' +  entry.name.to_s()  + "\n" 
		end
		respond_to do |format|
			format.text  { render plain: assetArr }
		end
	end
	
	def newItemLabel
		l(:label_new_asset_item)
	end
	
	def newAsset
		true
	end
	
	def editItemLabel
		l(:label_edit_asset_item)
	end
	
	def getIventoryListHeader
		headerHash = { 'project_name' => l(:label_project), 'product_name' => l(:label_product), 'parent_name' => l(:field_name), 'asset_name' => l(:label_components),  'product_attribute_name' => l(:label_attribute), 'serial_number' => l(:label_serial_number), 'owner_type' => l(:label_owner), 'rate' => l(:label_rate),  "is_loggable" => l(:label_loggable_asset),  'location_name' => l(:label_location) }
	end
	
	def showProductItem
		true
	end
	
	def showAdditionalInfo
		false
	end
	
	def showInventoryFields
		true
	end
	
	def sectionHeader
		l(:label_components)
	end
	
	def loggableAssetLbl
		l(:label_loggable_asset)
	end
	
	def loggableRateLbl
		l(:label_log) + " " + l(:label_rate)
	end
	
	def lblAsset
		l(:label_asset)
	end
	
	def editcomponentLbl
		l(:label_edit_component)
	end

	def dispose_asset
		inventory_item_id = params[:inventory_item_id].to_i
		@disposeAssetEntry = WkAssetProperty.disposeAsset(inventory_item_id).first
		@depreciationAmount = getRemainingDepreciation(@disposeAssetEntry, inventory_item_id)
	end

	def updateDisposedAsset
		sysCurrency = Setting.plugin_redmine_wktime['wktime_currency']
		assetProperty = WkAssetProperty.find(params[:asset_property_id])
		assetProperty.is_disposed = true
		assetProperty.disposed_rate = params[:dispose_amount].to_f
		#update Remaining Depreciation
		depreciation = WkAssetDepreciation.new
		depreciation.depreciation_date = Date.today
		depreciation.currency = sysCurrency
		depreciation.inventory_item_id = params[:inventory_item_id]
		depreciation.actual_amount = params[:asset_previous_value].to_f
		depreciation.depreciation_amount = params[:depreciation_amount].to_f
		
		if assetProperty.is_disposed && assetProperty.save() && depreciation.save()
			assetLedgerId = assetProperty.inventory_item.product_item.product.ledger_id
			assetReceiptLedgerId = getSettingCfId("asset_receipt_ledger")
			assetSaleLedgerId = getSettingCfId("asset_sale_ledger")
			if assetLedgerId && assetSaleLedgerId > 0 && assetReceiptLedgerId > 0
				transAmounts = []
				asset_value = (assetProperty.disposed_rate - params[:asset_current_value].to_f).round(2)
				transAmounts << {assetLedgerId => params[:asset_current_value].to_f, "detail_type" => "c"}
				transAmounts << {assetSaleLedgerId => asset_value.abs, "detail_type" => asset_value > 0 ? "c" : "d"}
				transAmounts << {assetReceiptLedgerId => assetProperty.disposed_rate, "detail_type" => "d"}
				isDiffCur = Setting.plugin_redmine_wktime['wktime_currency'] != assetProperty.currency
				glTransaction = saveGlTransaction("asset", nil, Date.today, 'J', nil, transAmounts, sysCurrency, isDiffCur, nil)
				unless glTransaction.blank?
					WkAssetProperty.where(:id => assetProperty.id).update(gl_transaction_id: glTransaction.id)
				end
			end
			unless assetLedgerId.blank?
				productDepAmtHash = { assetLedgerId => depreciation.depreciation_amount}
				postDepreciationToAccouning([depreciation.id], [depreciation.gl_transaction_id], depreciation.depreciation_date, productDepAmtHash, depreciation.depreciation_amount, sysCurrency)
			end
			WkAssetProperty.dispose_asset_notification(assetProperty) if WkNotification.notify('disposeAsset')
			redirect_to controller: controller_name, action:"index", tab: controller_name
			flash[:notice] = l(:notice_successful_update)
		else
			redirect_to controller: controller_name, action: "dispose_asset", inventory_item_id: params[:inventory_item_id], tab: controller_name
			flash[:error] = assetProperty.errors.full_messages.join("<br>")
		end
	end

end
