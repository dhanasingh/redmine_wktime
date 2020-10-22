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

class WkLead < ActiveRecord::Base
  unloadable
  has_many :activities, as: :parent, class_name: 'WkCrmActivity', :dependent => :destroy
  belongs_to :account, :class_name => 'WkAccount'
  belongs_to :created_by_user, :class_name => 'User'
  belongs_to :address, :class_name => 'WkAddress'
  belongs_to :contact, :class_name => 'WkCrmContact', :dependent => :destroy
  before_save :update_status_update_on 
  after_create_commit :send_notification
  after_save :lead_notification
  
  def update_status_update_on
	self.status_update_on = DateTime.now if status_changed?
  end
  
  def name
	contact.name unless contact.blank?
  end
  
  def lead_notification
    if status? && status == "C" && WkNotification.notify('leadConverted')
      emailNotes = "Lead : " + (self.account ? self.account.name : self.contact.name) + " has been converted " + "\n\n" + l(:label_redmine_administrator)
      subject = l(:label_lead) + " " + l(:label_notification)
      userId = (WkPermission.permissionUser('B_CRM_PRVLG') + WkPermission.permissionUser('A_CRM_PRVLG')).uniq
      WkNotification.notification(userId, emailNotes, subject)
    end
  end

  def send_notification
    if WkNotification.notify('leadGenerated')
      emailNotes = "Lead : " + (self.account ? self.account.name : self.contact.name) + " has been generated " + "\n\n" + l(:label_redmine_administrator)
      subject = l(:label_lead) + " " + l(:label_notification)
      userId = (WkPermission.permissionUser('B_CRM_PRVLG') + WkPermission.permissionUser('A_CRM_PRVLG')).uniq
      WkNotification.notification(userId, emailNotes, subject)
    end
  end

end
