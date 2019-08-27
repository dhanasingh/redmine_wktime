# ERPmine - ERP for service industry
# Copyright (C) 2011-2016  Adhi software pvt ltd
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

class WkInvoice < ActiveRecord::Base
  unloadable
  #belongs_to :account, :class_name => 'WkAccount'
  belongs_to :parent, :polymorphic => true
  belongs_to :modifier , :class_name => 'User'
  belongs_to :gl_transaction , :class_name => 'WkGlTransaction', :dependent => :destroy
  has_many :invoice_items, foreign_key: "invoice_id", class_name: "WkInvoiceItem", :dependent => :destroy
  has_many :projects, through: :invoice_items
  has_many :payment_items, foreign_key: "invoice_id", class_name: "WkPaymentItem", :dependent => :restrict_with_error
  has_one :rfq_quote, foreign_key: "quote_id", class_name: "WkRfqQuote"
  has_one :po_quote, foreign_key: "purchase_order_id", class_name: "WkPoQuote"
  has_one :quote_po, foreign_key: "quote_id", class_name: "WkPoQuote"
  has_one :sup_inv_po, foreign_key: "supplier_inv_id", class_name: "WkPoSupplierInvoice"
  has_one :po_sup_inv, foreign_key: "purchase_order_id", class_name: "WkPoSupplierInvoice"
  
  # scope :invoices, lambda {where :invoice_type => 'I'}
  # scope :quotes, lambda {where :invoice_type => 'Q'}
  # scope :purchase_orders, lambda {where :invoice_type => 'PO'}
  # scope :supplier_invoices, lambda {where :invoice_type => 'SI'}
  
  has_many :purchase_orders, through: :quote_po, :dependent => :restrict_with_error
  has_many :supplier_invoices, through: :po_sup_inv, :dependent => :restrict_with_error
  # attr_protected :modifier_id
  
  #validates_presence_of :account_id
  validates_presence_of :parent_id, :parent_type
  
  before_save :increase_inv_key
  
  def total_invoice_amount
	self.invoice_items.sum(:original_amount)
  end
  
  def total_paid_amount
	self.payment_items.current_items.sum(:original_amount)
  end
  
  def increase_inv_key  
	lastInvKey = WkInvoice.where(:invoice_type => invoice_type).maximum(:invoice_num_key)
	self.invoice_num_key = lastInvKey.blank? ? 1 : (lastInvKey + 1) if self.new_record?
	self.invoice_number = self.invoice_number.blank? ? self.invoice_num_key.to_s : self.invoice_number.to_s + self.invoice_num_key.to_s if self.new_record?
  end
  
end
