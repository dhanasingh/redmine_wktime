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
  # attr_protected :modifier_id
  
  #validates_presence_of :account_id
  validates_presence_of :parent_id, :parent_type
  
end
