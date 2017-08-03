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

class WkProductItem < ActiveRecord::Base
  unloadable
  # belongs_to :shipment, :class_name => 'WkShipment'
  belongs_to :product, :class_name => 'WkProduct'
  belongs_to :product_attribute, :class_name => 'WkProductAttribute'
  # belongs_to :supplier_invoice, foreign_key: "supplier_invoice_id", class_name: "WkInvoice"
  # belongs_to :purchase_order, foreign_key: "purchase_order_id", class_name: "WkInvoice"
  # belongs_to :location, :class_name => 'WkLocation'
  belongs_to :brand, :class_name => 'WkBrand'
  has_many :inventory_items, foreign_key: "product_item_id", class_name: "WkInventoryItem"
  # belongs_to :parent, foreign_key: "parent_id", class_name: "WkProductItem"
  
end
