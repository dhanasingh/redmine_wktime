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

class WkPayment < ActiveRecord::Base
  unloadable
  #belongs_to :account, :class_name => 'WkAccount'
  belongs_to :parent, :polymorphic => true
  belongs_to :account, -> { where(wk_payments: {parent_type: 'WkAccount'}) }, foreign_key: 'parent_id', :class_name => 'WkAccount'
  belongs_to :contact, -> { where(wk_payments: {parent_type: 'WkCrmContact'}) }, foreign_key: 'parent_id', :class_name => 'WkCrmContact'
  belongs_to :modifier , :class_name => 'User'
  has_many :payment_items, foreign_key: "payment_id", class_name: "WkPaymentItem", :dependent => :destroy
  has_many :invoices, through: :payment_items
  belongs_to :gl_transaction , :class_name => 'WkGlTransaction', :dependent => :destroy
  has_many :notifications, as: :source, class_name: "WkUserNotification", :dependent => :destroy
  # attr_protected :modifier_id

  #validates_presence_of :account_id
  validates_presence_of :parent_id, :parent_type
  # after_create_commit :send_notification

  scope :getPaymentItems, ->(payment){
    payment.payment_items.where({is_deleted: false})
    .sum(:original_amount)
  }

  def self.send_notification(payment)
    if WkNotification.notify('paymentReceived') && (payment.parent.class.name == 'WkAccount' && payment&.parent&.account_type == 'A' || payment.parent.class.name == 'WkCrmContact' && payment&.parent&.contact_type == 'C')
      emailNotes = l(:label_received_payment)+" #"+payment.id.to_s+": "+payment.payment_items.first.original_currency.to_s+""+WkPayment.getPaymentItems(payment).to_s+" "+l(:label_from)+" "+ payment.parent.name.to_s+" "+l(:label_for)+" "+payment.payment_date.to_s + "\n\n" + l(:label_redmine_administrator)
      userId = WkPermission.permissionUser('M_BILL').uniq
      subject = l(:label_payments) + " " + l(:label_notification)
      WkNotification.notification(userId, emailNotes, subject, payment, 'paymentReceived')
    elsif WkNotification.notify('supplierPaymentSent') && (payment.parent.class.name == 'WkAccount' && payment&.parent.account_type == 'S' || payment.parent.class.name == 'WkCrmContact' && payment.parent.contact_type == 'SC')
      l(:label_received_sup_payment)+" #"+payment.id.to_s+": "+payment.payment_items.first.original_currency.to_s+ WkPayment.getPaymentItems(payment).to_s+" "+l(:label_from)+" "+payment.parent.name.to_s+" "+l(:label_for)+" "+payment.payment_date.to_s + "\n\n" + l(:label_redmine_administrator)
      userId = WkPermission.permissionUser('M_BILL').uniq
      subject = l(:label_payments) + " " + l(:label_notification)
      WkNotification.notification(userId, emailNotes, subject, payment, 'supplierPaymentSent')
    end
  end

end
