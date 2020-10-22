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

class WkRfqQuote < ActiveRecord::Base
  unloadable
  belongs_to :quote , :class_name => 'WkInvoice'
  belongs_to :rfq , :class_name => 'WkRfq'
  after_create_commit :send_notification

  def send_notification
    if WkNotification.notify('quoteReceived')
      emailNotes = "RFQ Quote: #" + self.quote.invoice_number+ " has been Received " + "\n\n" + l(:label_redmine_administrator)
      userId = (WkPermission.permissionUser('B_PUR_PRVLG') + WkPermission.permissionUser('A_PUR_PRVLG')).uniq
      subject = l(:label_quotes) + " " + l(:label_notification)
      WkNotification.notification(userId, emailNotes, subject)
    end
  end
end
