# ERPmine - ERP for service industry
# Copyright (C) 2011-2021  Adhi software pvt ltd
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

class WkPublicHoliday < ActiveRecord::Base

  belongs_to :location, class_name: 'WkLocation'
  scope :getHolidays, ->(userID, holiday){
    joins("INNER JOIN wk_users ON wk_users.location_id = wk_public_holidays.location_id")
    .where("wk_users.user_id = #{userID} AND holiday_date = '#{holiday}'")
  }
end