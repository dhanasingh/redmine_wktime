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

class WkUser < ActiveRecord::Base
  include Redmine::SafeAttributes
  belongs_to :user
  belongs_to :role
  serialize :others
  
  # attr_protected :others, :user_id
  
  
  safe_attributes 	'role_id', 'id1','id2', 'id3',
					'join_date', 'birth_date', 'termination_date',  'gender',
					'bank_name','account_number', 'bank_code', 'loan_acc_number', 'tax_id', 'ss_id', 'custom_number1', 'custom_number2','custom_date1', 'custom_date2', 'is_schedulable', 'billing_rate', 'billing_currency', 'location_id', 'department_id', 'address_id', 'shift_id', 'created_by_user_id', 'updated_by_user_id'

 
  belongs_to :location, :class_name => 'WkLocation'
  belongs_to :department, :class_name => 'WkCrmEnumeration'
  
  belongs_to :address, :foreign_key => 'address_id', :dependent => :destroy, :class_name => 'WkAddress'
  
end
