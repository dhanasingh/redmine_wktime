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
	include WkopportunityHelper

	def formNotificationText(notification)
		notifyHash = {}
		return nil if notification.blank? || notification.source.blank?
		case WkUserNotification.getnotificationAction(notification)&.first&.name
		when "fillSurvey"
			notification.source.survey_for_id ||= User.current.id if notification.source.present? && notification&.source&.survey_for_type == 'User'
			notifyHash['text'] = l(:label_complete_survey)+" "+notification&.source&.name.to_s
			notifyHash['url'] = {controller:'wksurvey', action:'survey', surveyForID: notification&.source&.survey_for_id, surveyForType: notification&.source&.survey_for_type, survey_id: notification.source_id, id: notification.source_id} if notification&.source&.survey_for_type.blank? || notification&.source&.survey_for_type.present? && notification&.source&.survey_for_id.present?
			notifyHash['icon'] = "fa fa-file-text-o"
		when "leaveRequested"
			notifyHash['text'] = l(:label_approve_leave)+" "+notification&.source&.user.name.to_s+" "+l(:label_on)+" "+notification&.source&.start_date.to_date.to_s
			notifyHash['url'] = {controller:'wkleaverequest', action:'edit', id: notification.source_id}
			notifyHash['icon'] = "fa fa-user-circle"
		when "leaveApproved"
			notifyHash['text'] = notification.source&.status == 'A' ? l(:label_your_leave)+" "+notification&.source&.start_date.to_date.to_s+" "+l(:label_is_approved) : l(:label_your_leave)+" "+notification&.source&.start_date.to_date.to_s+" "+l(:label_rejected)
			notifyHash['url'] = {controller:'wkleaverequest', action:'edit', id: notification.source_id}
			notifyHash['icon'] = "fa fa-user-circle"
		when 'invoiceGenerated'
			notifyHash['text'] = l(:label_invoice)+" "+notification&.source&.invoice_items&.first&.original_currency.to_s+notification&.source&.invoice_items&.sum(:original_amount).to_s+" "+ l(:label_has_generated)+" "+ l(:label_for)+" "+notification&.source&.parent&.name&.to_s
			notifyHash['url'] = {controller:'wkinvoice', action:'edit', invoice_id: notification.source_id, new_invoice: false, preview_billing: false, tab: 'wkinvoice', id: notification.source_id}
			notifyHash['icon']= "fa fa-usd"
		when "paymentReceived"
			notifyHash['text'] = l(:label_received_payment)+" "+notification&.source&.payment_items&.first&.original_currency.to_s+WkPayment.getPaymentItems(notification.source).to_s+" "+l(:label_from)+" "+notification&.source&.parent&.name.to_s
			notifyHash['url'] = {controller:'wkpayment', action:'edit', payment_id: notification.source_id, id: notification.source_id}
			notifyHash['icon'] = "fa fa-usd"
		when 'contractSigned'
			notifyHash['text'] = l(:label_contract)+" "+notification.source_id.to_s+" "+ l(:label_for)+" "+notification&.source&.parent.name.to_s+ " " +l(:label_has_created)
			notifyHash['url'] = {controller:'wkcontract', action:'edit', contract_id: notification.source_id, id: notification.source_id}
			notifyHash['icon'] = "fa fa-file-text-o"
		when "nonSubmission"
			notifyHash['text'] = l(:button_submit)+" "+ l(:label_timesheet_on)+" "+notification&.source&.begin_date.to_s
			notifyHash['url'] = {controller:'wktime', action:'edit', startday: notification&.source&.begin_date, user_id: notification&.source&.user_id}
			notifyHash['icon'] = "fa fa-clock-o"
		when 'timeApproved'
			notifyHash['text'] =  l(:button_wk_approve)+" "+l(:label_timesheet_on)+" "+notification&.source&.begin_date.to_s+" "+l(:label_for)+" "+notification&.source&.user.name.to_s
			notifyHash['url'] = {controller:'wktime', action:'edit', startday: notification&.source&.begin_date, user_id: notification&.source&.user_id}
			notifyHash['icon'] = "fa fa-clock-o"
		when 'timeExceeded'
			notifyHash['text'] = "##{notification&.source&.id} - " + notification&.source&.subject&.to_s + " " + l(:label_exc_est)
			notifyHash['url'] = {controller: 'issues', id: notification&.source&.id, action: 'show'}
			notifyHash['icon'] = "fa fa-clock-o"
		when 'timeRejected'
			notifyHash['text'] = l(:label_timesheet_rejected)+" "+l(:label_on)+" "+notification&.source&.submitted_on.to_s
			notifyHash['url'] = {controller:'wktime', action:'edit', startday: notification&.source&.begin_date, user_id: notification&.source&.user_id}
			notifyHash['icon'] = "fa fa-clock-o"
		when 'surveyClosed'
			notifyHash['text'] = l(:label_survey)+" "+notification&.source&.name.to_s+" "+l(:label_has_closed)
			notifyHash['url'] = {controller:'wksurvey', action:'survey', survey_id: notification.source_id, id: notification.source_id}
			notifyHash['icon'] = "fa fa-file-text-o"
		when 'leadGenerated'
			leadNotifyLabel(notification)
			notifyHash['text'] = @label+" "+notification&.source&.name.to_s+" "+l(:label_has_created)
			notifyHash['url'] = {controller: @controller, action:'edit',lead_id: notification.source_id, id: notification.source_id}
			notifyHash['icon'] = "fa fa-user-circle"
		when 'leadConverted'
			leadNotifyLabel(notification)
			notifyHash['text'] = @label+" "+notification&.source&.name.to_s+" "+ @text
			notifyHash['url'] = {controller: @controller, action:'edit',lead_id: notification.source_id, id: notification.source_id}
			notifyHash['icon'] = "fa fa-user-circle"
		when 'opportunityStatusChanged'
			status_name = getSaleStageHash[get_sales_stage(notification.source)].present? ? getSaleStageHash[get_sales_stage(notification.source)] : ""
			notifyHash['text'] = l(:label_opportunity)+" "+notification&.source&.name.to_s+" "+l(:label_has_changed)+" "+status_name
			notifyHash['url'] = {controller:'wkopportunity', action:'edit',opp_id: notification.source_id, id: notification.source_id}
			notifyHash['icon'] = "fa fa-file-text-o"
		when 'salesActivityCompleted'
			notifyHash['text'] = l(:report_sales_activity)+" "+notification&.source&.name.to_s+" "+l(:label_has_completed)
			notifyHash['url'] = {controller:'wkcrmactivity', action:'edit',activity_id: notification.source_id, id: notification.source_id}
			notifyHash['icon'] = "fa fa-file-text-o"
		when 'receiveGoods'
			notifyHash['text'] = l(:label_shipment)+" "+l(:label_has_created)
			notifyHash['url'] = {controller:'wkshipment', action:'edit',shipment_id: notification.source_id, id: notification.source_id}
			notifyHash['icon'] = "fa fa-file-text-o"
		when 'disposeAsset'
			notifyHash['text'] = l(:label_asset)+" "+notification&.source&.name.to_s+" "+l(:label_has_disposed)
			notifyHash['url'] = {controller:'wkasset', action:'edit',inventory_item_id: notification&.source&.inventory_item_id, id: notification&.source&.inventory_item_id}
			notifyHash['icon'] = "fa fa-file-text-o"
		when 'rfqCreated'
			notifyHash['text'] = l(:label_rfq)+" "+notification&.source&.name.to_s+" "+l(:label_has_created)
			notifyHash['url'] = {controller:'wkrfq', action:'edit',rfq_id: notification.source_id, id: notification.source_id}
			notifyHash['icon'] = "fa fa-file-text-o"
		when 'quoteReceived'
			notifyHash['text'] = l(:label_rfq)+" "+l(:label_quote)+" #"+notification.source&.quote&.invoice_number.to_s+" "+l(:label_has_received)
			notifyHash['url'] = {controller:'wkquote', action:'edit',invoice_id: notification&.source&.quote_id, new_invoice: false, preview_billing:false, id: notification&.source&.quote_id}
			notifyHash['icon'] = "fa fa-file-text-o"
		when 'purchaseOrderGenerated'
			notifyHash['text'] = l(:label_purchase_order)+" #"+notification.source&.purchase_order&.invoice_number.to_s+" "+l(:label_has_created)
			notifyHash['url'] = {controller:'wkpurchaseorder', action:'edit',invoice_id: notification&.source&.purchase_order_id, new_invoice: false, preview_billing:false, id: notification&.source&.purchase_order_id}
			notifyHash['icon'] = "fa fa-file-text-o"
		when 'supplierInvoiceReceived'
			notifyHash['text'] = l(:label_supplier_invoice)+" "+notification.source&.invoice_items.first.original_currency.to_s+notification.source&.invoice_items.sum(:original_amount).to_s+" "+ l(:label_has_generated)+" "+ l(:label_for)+" "+notification.source&.parent&.name.to_s
			notifyHash['url'] = {controller:'wksupplierinvoice', action:'edit', invoice_id: notification.source_id, new_invoice: false, preview_billing: false, tab: 'wksupplierinvoice', id: notification.source_id}
			notifyHash['icon'] = "fa fa-usd"
		when 'supplierPaymentSent'
			notifyHash['text'] = l(:label_received_sup_payment)+" "+notification&.source&.payment_items.first.original_currency.to_s+WkPayment.getPaymentItems(notification.source).to_s+" "+l(:label_from)+" "+notification&.source&.parent.name.to_s
			notifyHash['url'] = {controller:'wksupplierpayment', action:'edit', payment_id: notification.source_id, id: notification.source_id}
			notifyHash['icon'] = "fa fa-usd"
		end
		notifyHash
	end

	def getnotifyDate(date)
		noOfdays = (DateTime.now - date.to_datetime).to_i
		case noOfdays
		when 0
			hours = ((DateTime.now.to_time - date.to_time) / 1.hour).to_i
			dateText = hours == 0 ? l(:label_just_now) : hours.to_s+" "+l(:label_hours_ago)
		when 1..6
			dateText = noOfdays.round().to_s+" "+l(:label_days_ago)
		when 7..31
			weeks = (noOfdays/7).to_i
			dateText = weeks.to_s+" "+l(:label_weeks_ago)
		when 32..365
			months = (noOfdays/31).to_i
			dateText = months.to_s+" "+l(:label_months_ago)
		else
			years = (noOfdays/365).to_i
			dateText = years.to_s+" "+l(:label_years_ago)
		end
		dateText
	end

	def leadNotifyLabel(notification)
		@label = l(:label_lead)
		@controller = 'wklead'
		@text = l(:label_has_converted)
		if notification&.source&.contact&.contact_type == 'IC'
			@label = l(:label_referral)
			@controller = 'wkreferrals'
			@text = l(:label_convert_employeee)
		end
	end
end
