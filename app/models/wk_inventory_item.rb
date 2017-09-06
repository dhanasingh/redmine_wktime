# ERPmine - ERP for service industry
# Copyright (C) 2011-2017  Adhi software pvt ltd
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

class WkInventoryItem < ActiveRecord::Base
  unloadable
  belongs_to :shipment, :class_name => 'WkShipment'
  belongs_to :product_item, :class_name => 'WkProductItem'
  belongs_to :supplier_invoice, foreign_key: "supplier_invoice_id", class_name: "WkInvoice"
  belongs_to :purchase_order, foreign_key: "purchase_order_id", class_name: "WkInvoice"
  belongs_to :location, :class_name => 'WkLocation'
  belongs_to :parent, foreign_key: "parent_id", class_name: "WkInventoryItem"
  belongs_to :uom, class_name: "WkMesureUnit"
  belongs_to :product_attribute, :class_name => 'WkProductAttribute'
  has_many :material_entries, foreign_key: "inventory_item_id", class_name: "WkMaterialEntry", :dependent => :restrict_with_error
  has_many :transfered_items, foreign_key: "parent_id", class_name: "WkInventoryItem", :dependent => :restrict_with_error
  
  before_destroy :add_quantity_to_parent
  validates_presence_of :product_item, :total_quantity, :available_quantity

  
  def incrementAvaQty(incVal)
	self.available_quantity += incVal
  end
  
  def add_quantity_to_parent
	unless self.parent_id.blank? || self.material_entries.count>0 || self.transfered_items.count>0
		parentObj = self.parent
		parentObj.available_quantity = self.total_quantity + parentObj.available_quantity
		parentObj.save
	end
  end
  
end
