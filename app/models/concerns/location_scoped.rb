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

# Location default_scope. Filters records to the current user's permitted location
# subtree on ALL controller actions (WkCurrent.location_scope_active is set by
# WkbaseController for every action). For unrestricted/ADM_ERP users,
# accessible_location_ids returns nil and the scope is a no-op.
# System methods that must bypass the filter (e.g. attendance/payroll calculations)
# should call .unscoped explicitly.
# Include in models with a direct `location_id` column.
module LocationScoped
  extend ActiveSupport::Concern

  included do
    default_scope {
      if WkCurrent.location_scope_active && (ids = WkLocation.accessible_location_ids)
        where(location_id: ids)
      else
        all
      end
    }
  end
end
