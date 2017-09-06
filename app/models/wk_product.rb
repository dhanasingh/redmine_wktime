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

class WkProduct < ActiveRecord::Base
  unloadable
  belongs_to :category, :class_name => 'WkProductCategory'
  has_many :product_items, foreign_key: "product_id", class_name: "WkProductItem", :dependent => :restrict_with_error
  has_many :inventory_items, through: :product_items
  has_many :product_brands, foreign_key: "product_id", class_name: "WkBrandProduct", :dependent => :destroy
  has_many :brands, through: :product_brands
  belongs_to :category, :class_name => 'WkProductCategory'
  belongs_to :attribute_group, :class_name => 'WkAttributeGroup'
  has_many :product_attributes, through: :attribute_group
  has_many :product_models, foreign_key: "product_id", class_name: "WkProductModel", :dependent => :destroy
  belongs_to :uom, class_name: "WkMesureUnit"
  has_many :product_taxes, foreign_key: "product_id", class_name: "WkProductTax", :dependent => :destroy
  has_many :taxes, through: :product_taxes
  
  validates_presence_of :category
end
