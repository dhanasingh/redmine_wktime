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
module WkproductitemHelper
include WktimeHelper
include WkshipmentHelper
include WkassetHelper

	def parentArray(type, needBlank, loadDD, locationId, currentParent)
		parentArr = Array.new
		invItemObj = WkInventoryItem.where(:product_type => type, :parent_id => nil).includes(:asset_property)
		if loadDD
			invItemObj = invItemObj.where(:parent_id => nil).where(:wk_asset_properties => {:matterial_entry_id => nil} )
		end
		unless locationId.blank?
			invItemObj = invItemObj.where(:location_id => locationId)
		end
		unless currentParent.blank?
			invItemObj = invItemObj.where.not(:id => currentParent)
		end
		invItemObj.each do |entry|
			parentArr << [(entry.asset_property.blank? ? "" : entry.asset_property.name.to_s), entry.id] 
		end
		parentArr.unshift(["",""]) if needBlank
		parentArr
	end
	
	def componentsArray(apartmentId, needBlank, loadDD)
		bedArr = Array.new
		inventoryObj = WkInventoryItem.where(:parent_id => apartmentId).includes(:asset_property)#.where(:wk_asset_properties => {:matterial_entry_id => nil} )
		if loadDD
			inventoryObj = inventoryObj.where(:wk_asset_properties => {:matterial_entry_id => nil} )
		end
		inventoryObj.each do |entry|
			bedArr << [(entry.asset_property.blank? ? "" : entry.asset_property.name.to_s), entry.id]
		end
		bedArr.unshift(["",""]) if needBlank
		bedArr
	end
	
	def availabilityHash
		avlType ={
		    '' =>  "",
			'A' =>  l(:label_availability),
			'U' =>  l(:label_in_use)
		}
		avlType
		
	end

end
