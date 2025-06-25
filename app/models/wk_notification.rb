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

class WkNotification < ApplicationRecord
  has_many :wk_user_notifications, foreign_key: "notify_id", class_name: "WkUserNotification", :dependent => :destroy

  scope :getActiveNotification, -> { where(active: true) }
  scope :getUnseletedActions, ->(actionName){ where.not(name: actionName, active: false) }

  def self.notify(name)
    notification = WkNotification.where(name: name).first
    notification&.has_attribute?('active') && notification&.active || false
  end  
  
  def self.mail(name)
    notification = WkNotification.where(name: name).first
    notification&.active && notification&.email || false
  end

  def self.notification(userId, emailNotes, subject, model=nil, label=nil)
    userId.each do |id|
      user = User.find(id)
      WkMailer.email_user(subject, User.current.language, user.mail, emailNotes, nil).deliver_later if WkNotification.first.email
      WkUserNotification.userNotification(id, model, label) if model.present?
    end
  end

  def self.updateActivefalse(notifications)
    notifications.update_all(active: false)
  end
end
