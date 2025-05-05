# ERPmine - ERP for service industry
# Copyright (C) 2011-2020  Adhi software pvt ltd
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

class WkPermission < ApplicationRecord


  has_many :grpPermission, foreign_key: "permission_id", :class_name => 'WkGroupPermission', :dependent => :destroy
  has_many :group , :through => :grpPermission
  has_many :users, :through => :group

  before_create :create_record
  before_update :update_record

  scope :getPermissions, -> {
    joins(:grpPermission, :users)
    .select("count(wk_permissions.id), wk_permissions.short_name")
    .where("users.id = ? ", User.current.id )
    .group("users.id, wk_permissions.short_name")
  }

  def self.permissionUser(shortName)
		userIds = WkPermission.joins(:grpPermission)
      .joins("INNER JOIN groups_users AS GU ON wk_group_permissions.group_id = GU.group_id")
      .joins("INNER JOIN users ON GU.user_id = users.id" + get_comp_con('users'))
      .where("short_name = ?", shortName)
      .select("users.id as user_id")
    userIds.pluck(:user_id)
  end

  def create_record
    self.updated_at = Date.current
    self.created_at = Date.current
  end

  def update_record
    self.updated_at = Date.current
  end
end