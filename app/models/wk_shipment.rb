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

class WkShipment < ApplicationRecord

  #belongs_to :account, :class_name => 'WkAccount'
  belongs_to :parent, :polymorphic => true
  has_many :inventory_items, foreign_key: "shipment_id", class_name: "WkInventoryItem", :dependent => :destroy
  has_many :product_items, through: :inventory_items
  belongs_to :gl_transaction , :class_name => 'WkGlTransaction', :dependent => :destroy
  belongs_to :supplier_invoice, foreign_key: "supplier_invoice_id", class_name: "WkInvoice"
  #belongs_to :purchase_order, foreign_key: "purchase_order_id", class_name: "WkInvoice"
  belongs_to :product, foreign_key: "product_id", class_name: "WkProduct"
  after_create_commit :send_notification
  has_many :notifications, as: :source, class_name: "WkUserNotification", :dependent => :destroy
  has_many :delivery_items, foreign_key: "shipment_id", class_name: "WkDeliveryItem", :dependent => :destroy
  has_many :wkstatus, -> { where(status_for_type: 'WkShipment')}, foreign_key: "status_for_id", class_name: "WkStatus", :dependent => :destroy
  belongs_to :invoice, foreign_key: "invoice_id", class_name: "WkInvoice"
  accepts_nested_attributes_for :wkstatus, allow_destroy: true

  def send_notification
    if WkNotification.notify('receiveGoods') && self.shipment_type == 'I'
      emailNotes = l(:label_shipment)+" "+l(:label_has_created)+ "\n\n" + l(:label_redmine_administrator)
      userId = (WkPermission.permissionUser('V_INV') + WkPermission.permissionUser('D_INV')).uniq
      subject = l(:label_shipment) + " " + l(:label_notification)
      WkNotification.notification(userId, emailNotes, subject, self, "receiveGoods")
    end
  end

  def current_status
    self ? self&.wkstatus&.last&.status : ''
  end

end
