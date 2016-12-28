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

class WkBillingSchedule < ActiveRecord::Base
  unloadable
  
  belongs_to :account_project, :class_name => 'WkAccountProject', :foreign_key => 'account_project_id'
  belongs_to :invoice, :class_name => 'WkInvoice'
  
  validates_presence_of :milestone, :bill_date, :currency
  validates_numericality_of :amount, :allow_nil => false, :message => :invalid
end
