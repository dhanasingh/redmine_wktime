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

class WkContract < ApplicationRecord

  acts_as_attachable :view_permission => :view_files,
                    :edit_permission => :manage_files,
                    :delete_permission => :manage_files
  belongs_to :project
  #belongs_to :account, :class_name => 'WkAccount'
  belongs_to :parent, :polymorphic => true
  validate :end_date_is_after_start_date
  # after_create_commit :send_notification
  has_many :notifications, as: :source, class_name: "WkUserNotification", :dependent => :destroy

  def end_date_is_after_start_date
		if !end_date.blank?
			if end_date < start_date
				errors.add(:end_date, "cannot be before the start date")
			end
		end
	end

  def self.send_notification(contract)
    if WkNotification.notify('contractSigned')
      emailNotes = "Contract: #" + contract.id.to_s + " has been generated " + "\n\n" + l(:label_redmine_administrator)
      subject = l(:label_contracts) + " " + l(:label_notification)
      userId = WkPermission.permissionUser('M_BILL').uniq
      WkNotification.notification(userId, emailNotes, subject, contract, 'contractSigned')
    end
  end
end
