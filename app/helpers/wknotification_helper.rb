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
			notifyHash['url'] = {controller:'wksurvey', action:'survey', surveyForID: notification.source.survey_for_id, surveyForType: notification.source.survey_for_type, survey_id: notification.source_id} if notification.source.survey_for_id.present?
		when "leaveRequested"
			notifyHash['text'] = l(:label_approve_leave)+" "+notification.source.user.name.to_s+" "+notification.source.start_date.to_date.to_s
			notifyHash['url'] = {controller:'wkleaverequest', action:'edit', id: notification.source_id}
		when "leaveApproved"
			notifyHash['text'] = WkLeaveReq.getEntry(notification.source.id).status == 'A' ? l(:label_your_leave)+" "+notification.source.start_date.to_date.to_s+" "+l(:label_is_approved) : l(:label_your_leave)+" "+notification.source.start_date.to_date.to_s+" "+l(:label_rejected) 
			notifyHash['url'] = {controller:'wkleaverequest', action:'edit', id: notification.source_id}
		when 'invoiceGenerated'
			notifyHash['text'] = l(:label_invoice)+" "+notification.source.invoice_items.first.original_currency.to_s+notification.source.invoice_items.first.original_amount.to_s+" "+ l(:label_has_generated)+" "+ l(:label_for)+" "+notification.source.parent.name.to_s
			notifyHash['url'] = {controller:'wkinvoice', action:'edit', invoice_id: notification.source.id, new_invoice: false,preview_billing: false}
		when "paymentReceived"
			notifyHash['text'] = l(:label_received_payment)+" "+notification.source.payment_items.first.original_currency.to_s+WkPayment.getPaymentItems(notification.source).to_s+" "+l(:label_from)+notification.source.parent.name.to_s
			notifyHash['url'] = {controller:'wkpayment', action:'edit', payment_id: notification.source_id}
		when 'contractSigned'
			notifyHash['text'] = l(:label_contract)+" "+notification.source.id.to_s+" "+ l(:label_for)+" "+notification.source.parent.name.to_s+ " " +l(:label_has_generated)
			notifyHash['url'] = {controller:'wkcontract', action:'edit', contract_id: notification.source.id}
		when "nonSubmission"	
			notifyHash['text'] = l(:button_submit)+" "+ l(:label_timesheet_on)+" "+notification.source.begin_date.to_s
			notifyHash['url'] = {controller:'wktime', action:'edit', startday: notification.source.begin_date, user_id: notification.source.user_id}
		when 'timeApproved'
			notifyHash['text'] =  l(:button_wk_approve)+" "+l(:label_timesheet_on)+" "+notification.source.begin_date.to_s+" "+l(:label_for)+" "+notification.source.user.name.to_s
			notifyHash['url'] = {controller:'wktime', action:'edit', startday: notification.source.begin_date, user_id: notification.source.user_id}
		when 'timeRejected' 
			notifyHash['text'] = l(:label_rejected_timesheet)+" "+notification.source.submitted_on.to_s
			notifyHash['url'] = {controller:'wktime', action:'edit', startday: notification.source.begin_date, user_id: notification.source.user_id}
		when 'surveyClosed'
			notifyHash['text'] = l(:label_survey)+" "+notification.source.name.to_s+" "+l(:label_has_closed)
			notifyHash['url'] = {controller:'wksurvey', action:'survey',survey_id: notification.source.id}
		end
		notifyHash
	end

	def getnotifyDate(date)
		noOfdays = (DateTime.now - date.to_datetime).to_i
		case noOfdays
		when 0
			hours = ((DateTime.now.to_time - date.to_time) / 1.hour).to_i
			dateText = hours == 0 ? 'Just now' : hours.to_s + ' hours ago'
		when 1..6
			dateText = noOfdays.round().to_s + ' days ago'
		when 7..31
			weeks = (noOfdays/7).to_i
			dateText = weeks.to_s + ' weeks ago'
		when 32..365
			months = (noOfdays/31).to_i
			dateText = months.to_s + ' months ago'
		else
			years = (noOfdays/365).to_i
			dateText = years.to_s + ' years ago'
		end
		dateText
	end
end
