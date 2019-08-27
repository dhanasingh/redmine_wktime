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
class WkassetController < WkproductitemController
  unloadable
	menu_item :wkproduct
	include WktimeHelper


	def getItemType
		'A'
	end
	
	def showAssetProperties
		true
	end
	
	def getProductAsset
		assetArr = ""
		unless params[:id].blank?
			pctObj = WkInventoryItem.joins(:product_item, :asset_property).where(:wk_product_items => {:product_id => params[:id].to_i}, :product_type => 'A').select("wk_inventory_items.id, wk_asset_properties.name")
		else 
			pctObj = WkInventoryItem.joins(:product_item, :asset_property).where(:product_type => 'A').select("wk_inventory_items.id, wk_asset_properties.name")
		end
		
		pctObj.each do | entry |
			assetArr << entry.id.to_s() + ',' +  entry.name.to_s()  + "\n" 
		end
		respond_to do |format|
			format.text  { render :plain => assetArr }
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

end
