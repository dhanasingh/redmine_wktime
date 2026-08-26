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

# Per-request store for location-visibility. Rails auto-resets all
# ActiveSupport::CurrentAttributes subclasses at the end of each request, so
# nothing leaks across requests (the request_store gem is not installed).
class WkCurrent < ActiveSupport::CurrentAttributes
  # default_scope for index/edit/show/associations.
  attribute :location_scope_active

  # { user_id => accessible_location_ids } memo so resolution runs once/request.
  attribute :location_ids_cache

  # { user_id => permitted final (deepest-leaf) location ids } memo — edit forms
  # can render one dropdown per row, so the tree walk must run once per request.
  attribute :location_final_ids_cache
end
