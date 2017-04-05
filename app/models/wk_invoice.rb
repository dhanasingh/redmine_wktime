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
  has_many :payment_items, foreign_key: "invoice_id", class_name: "WkPaymentItem", :dependent => :destroy
  
  attr_protected :modifier_id
  
  #validates_presence_of :account_id
  validates_presence_of :parent_id, :parent_type
  
  def total_invoice_amount
	self.invoice_items.sum(:amount)
  end
  
  def total_paid_amount
	self.payment_items.sum(:amount)
  end
  
end
