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

class WkCrmActivity < ApplicationRecord

  belongs_to :parent, :polymorphic => true
  belongs_to :created_by_user, :class_name => 'User'
  belongs_to :assigned_user, :class_name => 'User'
  has_many :notifications, as: :source, class_name: "WkUserNotification", :dependent => :destroy
  validate :validate_crm_activity
  before_save :update_status_update_on
  after_save :activity_notification
  belongs_to :interview_type, class_name: "WkCrmEnumeration"

  acts_as_attachable :view_permission => :view_files,
                    :edit_permission => :manage_files,
                    :delete_permission => :manage_files

  def validate_crm_activity
	errors.add(:base, (l(:field_subject)  + " " + l('activerecord.errors.messages.blank'))) if name.blank?
	# if activity_type == 'T'
		# errors.add :start_date, :blank if name.blank?
		# errors.add :end_date, :blank if name.blank?
	# end

	# if activity_type == 'T'
		# errors.add :start_date, :blank if name.blank?
		# errors.add :end_date, :blank if name.blank?
	# end

	# if activity_type == 'M'
		# errors.add :start_date, :blank if name.blank?
	# end

  end

  def update_status_update_on
	self.status_update_on = DateTime.now if status_changed?
  end

	def activity_notification
    if status? && status == "C" && WkNotification.notify('salesActivityCompleted')
      emailNotes = l(:report_sales_activity)+" "+ self.name.to_s + " " +l(:label_has_completed)+" "+ "\n\n" + l(:label_redmine_administrator)
      subject = l(:label_activity) + " " + l(:label_notification)
      userId = (WkPermission.permissionUser('B_CRM_PRVLG') + WkPermission.permissionUser('A_CRM_PRVLG')).uniq
      WkNotification.notification(userId, emailNotes, subject, self, 'salesActivityCompleted')
    end
  end

  def self.getActivitiesEntries(from, to, userIdArr)
    entries = self.includes(:parent).where(start_date: from .. to).where("wk_crm_activities.activity_type != 'I'").order(updated_at: :desc)
    entries = entries.where(assigned_user_id: userIdArr) if userIdArr.present?
    entries
  end

end
