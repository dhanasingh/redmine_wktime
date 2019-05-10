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

class WkLocation < ActiveRecord::Base
  unloadable
  belongs_to :address, :class_name => 'WkAddress', :dependent => :destroy
  has_many :inventory_items, foreign_key: "location_id", class_name: "WkInventoryItem", :dependent => :restrict_with_error
  belongs_to :location_type, :class_name => 'WkCrmEnumeration'
  has_many :contacts, foreign_key: "location_id", class_name: "WkCrmContact", :dependent => :restrict_with_error
  has_many :acounts, foreign_key: "location_id", class_name: "WkAccount", :dependent => :restrict_with_error
  before_save :check_default, :check_main
  
  validates_presence_of :name
  
  def check_default
    if is_default? && is_default_changed?
      WkLocation.update_all({:is_default => false})
    end
  end 
  
  def check_main
    if is_main? && is_main_changed?
      WkLocation.update_all({:is_main => false})
    end
  end
end
