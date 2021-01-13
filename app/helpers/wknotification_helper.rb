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

module WknotificationHelper
  include WktimeHelper

	def formNotificationText(notification)
		notifyHash = {}
		if WkUserNotification.getnotificationAction(notification).first.present?
			case WkUserNotification.getnotificationAction(notification).first.name
			when "fillSurvey"
				notifyHash['text'] =  "Complete Survey: " + notification.source.name.to_s
				notifyHash['url'] = {controller:'wksurvey', action:'survey', survey_id: notification.source_id, only_path: true}
			when "leaveRequested"
				notifyHash['text'] = "Approve Leave for: " + notification.source.user.name.to_s + " " + notification.source.start_date.to_date.to_s
				notifyHash['url'] = {controller:'wkleaverequest', action:'edit', id: notification.source_id, only_path: true}
			when "leaveApproved"
				notifyHash['text'] = "Your leave for: " + notification.source.start_date.to_date.to_s + " is approved"
				notifyHash['url'] = {controller:'wkleaverequest', action:'edit', id: notification.source_id, only_path: true}
			when 'invoiceGenerated'
				notifyHash['text'] = "Invoice " + notification.source.invoice_items.first.original_amount.to_s + " has been generated for " + notification.source.parent.name.to_s
				notifyHash['url'] = {controller:'wkinvoice', action:'edit', invoice_id: notification.source.id, new_invoice: false,preview_billing: false, only_path: true}
			when "paymentReceived"
				notifyHash['text'] = "Receieved Payment "+ WkPayment.getPaymentItems(notification.source).to_s + " from " + notification.source.parent.name.to_s
				notifyHash['url'] = {controller:'wkpayment', action:'edit', payment_id: notification.source_id, only_path: true}
			when 'contractSigned'
				notifyHash['text'] = "Contract " + notification.source.id.to_s + " for " + notification.source.parent.name.to_s + " has been generated"
				notifyHash['url'] = {controller:'wkcontract', action:'edit', contract_id: notification.source.id, only_path: true}
			when "nonSubmission"	
				notifyHash['text'] = "submit timesheet on "+ notification.source.begin_date.to_s
				notifyHash['url'] = {controller:'wktime', action:'edit', startday: notification.source.begin_date, user_id: notification.source.user_id, only_path: true}
			when 'timeApproved'
				notifyHash['text'] = "Approve timesheet on " +  notification.source.begin_date.to_s + " for " + notification.source.user.name.to_s
				notifyHash['url'] = {controller:'wktime', action:'edit', startday: notification.source.begin_date, user_id: notification.source.user_id, only_path: true}
			when 'timeRejected' 
				notifyHash['text'] = "Rejected timesheet " + notification.source.submitted_on.to_s
				notifyHash['url'] = {controller:'wktime', action:'edit', startday: notification.source.begin_date, user_id: notification.source.user_id, only_path: true}
			end
		end
		notifyHash
	end
end
