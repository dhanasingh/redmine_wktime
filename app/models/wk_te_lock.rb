# ERPmine - ERP for service industry
# Copyright (C) 2011-  Adhi software pvt ltd
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

class WkTeLock < ApplicationRecord

   include Redmine::SafeAttributes
   belongs_to :creator, :class_name => 'User', :foreign_key => 'locked_by'
   belongs_to :updater, :class_name => 'User', :foreign_key => 'updated_by'
  safe_attributes 'lock_date', 'locked_by', 'updated_by'
  # attr_protected :locked_by, :updated_by

  validates_presence_of :lock_date

   def initialize(attributes=nil, *args)
    super
  end

   def lock_date=(date)
		super
		if lock_date.is_a?(Time)
		  self.lock_date = lock_date.to_date
		end
	end
	def created_on=(date)
		super
		if lock_date.is_a?(Time)
		  self.created_on = created_on.to_date
		end
	end
end
