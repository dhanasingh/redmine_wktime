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

class WkUserNotification < ApplicationRecord

  belongs_to :notification , :class_name => 'WkNotification', :foreign_key => 'notify_id'
  belongs_to :source, :polymorphic => true

  def self.userNotification(userId, model, label)
    notifyID = WkNotification.where("name = ?", label).pluck(:id).first
    userNotify = WkUserNotification.new
    userNotify.user_id = userId
    userNotify.notify_id = notifyID
    userNotify.seen = false
    userNotify.seen_on = nil
    userNotify.source_type = model.class.name
    userNotify.source_id = model.id
    userNotify.save
  end

  scope :unreadNotification, -> {
    where({user_id: User.current.id ,seen: false })
  }

  scope :getnotificationAction, ->(usrNotification){
    joins(:notification)
    .where("wk_notifications.id = #{usrNotification.notify_id}")
    .select("wk_notifications.name")
  }
end
