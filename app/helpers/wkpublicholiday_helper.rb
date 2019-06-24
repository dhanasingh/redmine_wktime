# ERPmine - ERP for service industry
# Copyright (C) 2011-2018  Adhi software pvt ltd
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
module WkpublicholidayHelper
  include WktimeHelper
  include WkcrmenumerationHelper
  include CalendarsHelper

  def selectLocation(model, locId)
    ddArray = Array.new
    ddValues = model.all
    unless ddValues.blank?
        ddValues.each do | entry |
            ddArray << [ entry.name, entry.id ]
            locId = entry.id if locId.nil? && entry.is_default?
        end
    end
    ddArray.unshift(["","0"],[l(:label_all_locations),'All'])
    options_for_select(ddArray, :selected => locId)
  end
end
