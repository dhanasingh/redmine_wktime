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

class WkAssetProperty < ApplicationRecord


  belongs_to :inventory_item, :class_name => 'WkInventoryItem'
  belongs_to :material_entry, foreign_key: "matterial_entry_id", class_name: "WkMaterialEntry"
  scope :available_assets,  -> { where(:matterial_entry_id => nil) }
  has_many :notifications, as: :source, class_name: "WkUserNotification", :dependent => :destroy

  scope :disposeAsset, ->(inventory_item_id){
    joins("LEFT JOIN wk_asset_depreciations AS ad ON ad.inventory_item_id = wk_asset_properties.inventory_item_id"+ get_comp_con('ad'))
    .joins("LEFT JOIN (
      SELECT MAX(depreciation_date) AS depreciation_date, inventory_item_id
      FROM wk_asset_depreciations where inventory_item_id =#{inventory_item_id}
      "+ get_comp_con('wk_asset_depreciations')+" group by inventory_item_id
      )  AS D  ON D.inventory_item_id = ad.inventory_item_id  AND D.depreciation_date = ad.depreciation_date")
    .joins("LEFT JOIN wk_inventory_items AS it ON wk_asset_properties.inventory_item_id = it.id"+ get_comp_con('it'))
    .joins("LEFT JOIN wk_shipments AS s ON it.shipment_id = s.id"+ get_comp_con('s'))
    .where("wk_asset_properties.inventory_item_id =#{inventory_item_id} AND (ad.depreciation_date IS NULL OR
      ad.depreciation_date IS NOT NULL AND D.depreciation_date IS NOT NULL)")
    .select("wk_asset_properties.name, wk_asset_properties.id AS asset_property_id, wk_asset_properties.currency, is_disposed,
      disposed_rate, depreciation_amount,
      CASE WHEN wk_asset_properties.current_value IS NOT NULL THEN wk_asset_properties.current_value
           ELSE it.cost_price + it.over_head_price END AS current_value,
      CASE WHEN D.depreciation_date IS NULL THEN shipment_date ELSE D.depreciation_date END AS depreciation_date,
      CASE WHEN depreciation_amount IS NOT NULL THEN actual_amount - depreciation_amount
           WHEN wk_asset_properties.current_value IS NOT NULL THEN wk_asset_properties.current_value
           ELSE it.cost_price + it.over_head_price
      END AS previous_value")
  }

  def self.dispose_asset_notification(assetProperty)
    emailNotes = l(:label_asset)+": " + (assetProperty.name) +" "+l(:label_has_disposed) + "\n\n" + l(:label_redmine_administrator)
    subject = l(:label_asset) + " " + l(:label_notification)
    userId = (WkPermission.permissionUser('V_INV') + WkPermission.permissionUser('D_INV')).uniq
    WkNotification.notification(userId, emailNotes, subject, assetProperty, "disposeAsset")
  end

end
