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

class WkInventoryItem < ApplicationRecord

  belongs_to :shipment, :class_name => 'WkShipment'
  belongs_to :product_item, :class_name => 'WkProductItem'
  belongs_to :supplier_invoice, foreign_key: "supplier_invoice_id", class_name: "WkInvoice"
  belongs_to :purchase_order, foreign_key: "purchase_order_id", class_name: "WkInvoice"
  belongs_to :location, :class_name => 'WkLocation'
  belongs_to :parent, foreign_key: "parent_id", class_name: "WkInventoryItem"
  belongs_to :uom, class_name: "WkMesureUnit"
  belongs_to :product_attribute, :class_name => 'WkProductAttribute'
  belongs_to :project, :class_name => 'Project'
  has_many :material_entries, foreign_key: "inventory_item_id", class_name: "WkMaterialEntry", :dependent => :restrict_with_error
  has_many :transferred_items, foreign_key: "parent_id", class_name: "WkInventoryItem", :dependent => :restrict_with_error
  has_one :asset_property, foreign_key: "inventory_item_id", class_name: "WkAssetProperty", :dependent => :destroy
  has_many :depreciations, foreign_key: "inventory_item_id", class_name: "WkAssetDepreciation", :dependent => :restrict_with_error
  has_many :components, foreign_key: "parent_id", class_name: "WkInventoryItem", :dependent => :restrict_with_error
   scope :asset, lambda { where(:product_type => 'A') }
   scope :inventory, lambda { where(:product_type => 'I') }
   scope :shipment_item, lambda { where(:parent_id => nil) }
   scope :transferred_item, lambda { where.not(:from_id => nil) }
   belongs_to :from, foreign_key: "from_id", class_name: "WkInventoryItem"


  before_destroy :add_quantity_to_parent
  validates_presence_of :product_item, :total_quantity, :available_quantity


  def incrementAvaQty(incVal)
	  self.available_quantity += incVal
  end

  def add_quantity_to_parent
    if self.product_type == 'I'
      parentObj = self.from
      if parentObj.present? && self.parent_id.present?
        parentObj.available_quantity = self.total_quantity + parentObj.available_quantity
        parentObj.save
      end
    else
      unless self.parent_id.blank? || self.material_entries.count>0 || self.transferred_items.count>0
        parentObj = self.parent
        parentObj.available_quantity = self.total_quantity + parentObj.available_quantity
        parentObj.save
      end
    end
  end

  def assetName
    self.asset_property.blank? ? "" : self.asset_property.name
  end

  scope :get_delivery_entry, ->{
    joins(:product_item, :product_attribute)
    .joins("INNER JOIN wk_products ON wk_products.id = wk_product_items.product_id" + get_comp_con('wk_products'))
    .joins("INNER JOIN wk_brands ON wk_brands.id = wk_product_items.brand_id" + get_comp_con('wk_brands'))
    .joins("INNER JOIN wk_product_models ON wk_product_models.id = wk_product_items.product_model_id" + get_comp_con('wk_product_models'))
    .where("available_quantity > 0 AND (wk_inventory_items.product_type= 'I')" + get_comp_con('wk_inventory_items'))
  }

  scope :getProduct, ->{
    get_delivery_entry.group("wk_products.id, wk_products.name").select("wk_products.id, wk_products.name")
  }

  scope :getProductItem, ->(id, location_id){
    get_delivery_entry.where('wk_product_items.product_id': id, location_id: location_id).group("wk_inventory_items.id, wk_inventory_items.product_item_id, wk_inventory_items.currency, wk_inventory_items.selling_price, wk_inventory_items.serial_number, wk_inventory_items.running_sn").select("wk_inventory_items.id, wk_inventory_items.product_item_id, wk_inventory_items.currency, wk_inventory_items.selling_price, wk_inventory_items.serial_number, wk_inventory_items.running_sn")
  }

  scope :getProductDetails, ->(id){
    get_delivery_entry.where('wk_inventory_items.id': id).select("wk_inventory_items.*")
  }

  scope :get_assembled_component, ->(id){
    where(parent_id: id)
  }

  def self.getInventoryItems(item_type)
    product_type = item_type == 'm' ? 'I' : ['A', 'RA']
    inv_items = self.where(product_type: product_type)
  end
end
