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
  include WkleaverequestHelper

	def formNotificationText(notification)
		notifyHash = {}
		case WkUserNotification.getnotificationAction(notification).first.name
		when "fillSurvey"
			notifyHash['text'] = l(:label_complete_survey)+" "+notification.source.name.to_s
			notifyHash['url'] = {controller:'wksurvey', action:'survey', survey_id: notification.source_id, only_path: true}
		when "leaveRequested"
			notifyHash['text'] = l(:label_approve_leave)+" "+notification.source.user.name.to_s+" "+notification.source.start_date.to_date.to_s
			notifyHash['url'] = {controller:'wkleaverequest', action:'edit', id: notification.source_id, only_path: true}
		when "leaveApproved"
			notifyHash['text'] = WkLeaveReq.getEntry(notification.source.id).status == 'A' ? l(:label_your_leave)+" "+notification.source.start_date.to_date.to_s+" "+l(:label_is_approved) : l(:label_your_leave)+" "+notification.source.start_date.to_date.to_s+" "+l(:label_rejected) 
			notifyHash['url'] = {controller:'wkleaverequest', action:'edit', id: notification.source_id, only_path: true}
		when 'invoiceGenerated'
			notifyHash['text'] = l(:label_invoice)+" "+notification.source.invoice_items.first.original_currency.to_s+notification.source.invoice_items.first.original_amount.to_s+" "+ l(:label_has_generated)+ " " + notification.source.parent.name.to_s
			notifyHash['url'] = {controller:'wkinvoice', action:'edit', invoice_id: notification.source.id, new_invoice: false,preview_billing: false, only_path: true}
		when "paymentReceived"
			notifyHash['text'] = l(:label_received_payment)+" "+WkPayment.getPaymentItems(notification.source).to_s+" "+l(:label_date_from)+notification.source.parent.name.to_s
			notifyHash['url'] = {controller:'wkpayment', action:'edit', payment_id: notification.source_id, only_path: true}
		when 'contractSigned'
			notifyHash['text'] = l(:label_contract)+" "+notification.source.id.to_s+" "+ l(:label_for)+" "+notification.source.parent.name.to_s+ " " +l(:label_has_generated)
			notifyHash['url'] = {controller:'wkcontract', action:'edit', contract_id: notification.source.id, only_path: true}
		when "nonSubmission"	
			notifyHash['text'] = l(:button_submit)+" "+ l(:label_timesheet_on)+" "+notification.source.begin_date.to_s
			notifyHash['url'] = {controller:'wktime', action:'edit', startday: notification.source.begin_date, user_id: notification.source.user_id, only_path: true}
		when 'timeApproved'
			notifyHash['text'] =  l(:button_wk_approve)+" "+l(:label_timesheet_on)+" "+notification.source.begin_date.to_s+" "+l(:label_for)+" "+notification.source.user.name.to_s
			notifyHash['url'] = {controller:'wktime', action:'edit', startday: notification.source.begin_date, user_id: notification.source.user_id, only_path: true}
		when 'timeRejected' 
			notifyHash['text'] = l(:label_rejected_timesheet)+" "+notification.source.submitted_on.to_s
			notifyHash['url'] = {controller:'wktime', action:'edit', startday: notification.source.begin_date, user_id: notification.source.user_id, only_path: true}
		when 'surveyClosed'
			notifyHash['text'] = l(:label_survey)+" "+notification.source.name.to_s+" "+l(:label_has_closed)
			notifyHash['url'] = {controller:'wksurvey', action:'survey',survey_id: notification.source.id, only_path: true}
		end
		notifyHash
	end
end
