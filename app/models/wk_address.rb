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

class WkAddress < ActiveRecord::Base
  unloadable
  has_many :wk_accounts, foreign_key: "address_id", class_name: "WkAccount"
  has_many :wk_contacts, foreign_key: "address_id", class_name: "WkContact"
  has_many :wk_leads, foreign_key: "address_id", class_name: "WkLead"
  #validates_presence_of :address1, :work_phone, :fax, :city, :state, :country
  #validates_numericality_of :pin, :only_integer => true, :greater_than_or_equal_to => 0, :message => :invalid
  validate :hasAnyValues
  
  def hasAnyValues
	address1.blank? && address2.blank? && work_phone.blank? && home_phone.blank? && mobile.blank? && email.blank? && fax.blank? && city.blank? && country.blank? && state.blank? && pin.blank? && department.blank? && department.blank? && id.blank?
  end
end
