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

class WkProductItem < ApplicationRecord

  belongs_to :product, :class_name => 'WkProduct'
  belongs_to :brand, :class_name => 'WkBrand'
  belongs_to :product_model, :class_name => 'WkProductModel'
  has_many :inventory_items, foreign_key: "product_item_id", class_name: "WkInventoryItem", :dependent => :restrict_with_error
  validates_presence_of :product

  def self.getproductItems
    self.all.map{|i| [i&.product&.name.to_s + " " + i&.brand&.name.to_s + " " + i&.product_model&.name.to_s, i&.product&.id.to_s+", "+i.id.to_s]}
  end

  def self.getProductTax(id)
    prodItem = self.find(id)
    prodTax = prodItem&.product&.product_taxes
    prodName = (prodItem&.product&.name || "") +" "+ (prodItem&.brand&.name || "") +" "+ (prodItem&.product_model&.name || "")
    prodTax.map{|t| {name: t&.tax&.name, rate: t&.tax&.rate_pct, product: prodName, product_id: prodItem&.product&.id}}
  end
end
