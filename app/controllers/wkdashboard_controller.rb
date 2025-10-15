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

class WkdashboardController < WkbaseController

	before_action :require_login
	accept_api_auth :get_graphs, :get_detail_report
	include WkdashboardHelper
	include WkcrmHelper
	include WktimeHelper
	include WkpayrollHelper

	def index
		if showDashboard && hasSettingPerm
			set_filter_session
			setMembers
			retrieve_date_range
			get_inv_payment_balance if showBilling && validateERPPermission("M_BILL")
		else
			redirect_to set_module
		end
	end

	def graph(path=params[:gPath])
		data = {}
		group_id = session[controller_name].try(:[], :group_id)
		project_id = session[controller_name].try(:[], :project_id)
		setDateRange

		begin
			load(path)
			obj = getGraphModule(path)
			data = obj.chart_data({from: @from, to: @to, group_id: group_id, project_id: project_id})
			data[:url] = url_for(data[:url]) if data[:url].present?
		rescue
			data = {error: "404"}
		end

		if params[:gPath].blank?
			data[:gPath] = path
			return(data)
		else
			render(json: data)
		end
	end

	def get_detail_report
		if params[:dashboard_type] != "Emp"
			path = params[:gPath] if params[:gPath].present?
			data = nil
			group_id = session[controller_name].try(:[], :group_id)
			project_id = session[controller_name].try(:[], :project_id)
			setDateRange

			begin
				load(path)
				obj = getGraphModule(path)
				data = obj.get_detail_report({from: @from, to: @to, group_id: group_id, project_id: project_id})
			rescue
				data = {error: "404"}
			end
		else
			data = getEmpDetailReport()
		end

		render(json: (data || {}))
	end

	def setDateRange
		retrieve_date_range
		@from = params[:from].to_date if params[:from].present?
		@to = params[:to].to_date if params[:to].present?

		if @from.blank? && @to.blank?
			@to = User.current.today.end_of_month
			@from = User.current.today.end_of_month - 12.months + 1.days
		elsif @from.blank? && @to.present?
			@from = @to - 12.months + 1.days
		elsif @to.blank? && @from.present?
			@to = @from + 12.months - 1.days
		end
		@to = User.current.today if @to > User.current.today
	end

	def set_filter_session
		filters = [:project_id, :group_id, :period_type, :period, :from, :to]
		super(filters)
	end

	def setMembers
		@groups = Group.where(type: "Group").sorted.all
	end

	def get_graphs
		graphDetails = params[:dashboard_type] == "Emp" ? getEmpDashboard() : (get_graphs_yaml_path.sort).map{|path| graph(path)}
		render json: {graphs: graphDetails, unseen_count: @unseen_count}
	end

	def getEmpDashboard
		data = []
		if showAttendance
			leaves = WkUserLeave.leaveCounts.map{|l| {name: l.subject, value: l.leave_count&.round(1), issue_id: l.issue_id, type: "leave"}}
			data << {title: l(:label_wk_leave), data: leaves} if leaves.present?
		end
		if showPayroll
			salary = WkSalary.getLastSalary
			net = salary.present? ? (salary.currency + " " + sprintf('%.2f', salary.net)) : nil;
			lastIncSalary = WkSalary.lastIncrementSalary || {}
			lastIncSalary.merge!({name: l(:label_last_increment), type: "incrementSalary"})
			data << {title: l(:label_salary), data: [{name: l(:label_last_salary), type: "salary", value: net, date: salary&.salary_date}, lastIncSalary]}
		end
		return data
	end

	def getEmpDetailReport()
		case params[:type]
		when "salary"
			data = {graphName: l(:label_salary)}
			data[:header] = {date: l(:label_salarydate), net: l(:label_net)}
			data[:data] = (WkSalary.lastYearSalaries || []).map{|s| {date: s.salary_date, net: s.currency+ " " +sprintf('%.2f', s.net)}}
		when "incrementSalary"
			data = {graphName: l(:label_last_increment)}
			data[:header] = {date: l(:label_salarydate), net: l(:label_net)}
			data[:data] = (WkSalary.lastIncrementSalary(true) || [])
		when "leave"
			data = {graphName: WkUserLeave.getLeaveName(params[:issue_id]) || l(:label_wk_leave)}
			data[:header] = {date: l(:label_date), available: l(:label_availability), used: l(:wk_field_used), closing: l(:wk_label_closing)}
			leaves = WkUserLeave.detailReport(params[:issue_id])
			data[:data] = leaves.map{|l| {date: l.accrual_on, available: l.balance.to_i + l.accrual, used: l.used.to_i, closing: (l.balance.to_i + l.accrual.to_i - l.used.to_i)}}
		end
		data
	end

	def employee_dashboard
		set_filter_session
		setMembers
		retrieve_date_range
		@empDash = getEmpDashboard
	end

	def get_inv_payment_balance
		from = @from
		to   = @to
		range = getToDateTime(from)..getToDateTime(to) if from && to

		invoice_scope = WkInvoice.joins(:invoice_items).where(invoice_type: "I")
		payment_scope = WkPayment.joins(payment_items: :invoice)
														.where(wk_payment_items: { is_deleted: false }, wk_invoices: { invoice_type: "I" })

		@invoice = range ? invoice_scope.where(invoice_date: range).sum("wk_invoice_items.amount") : invoice_scope.sum("wk_invoice_items.amount")
		@payment = range ? payment_scope.where(payment_date: range).sum("wk_payment_items.amount") : payment_scope.sum("wk_payment_items.amount")

		total_invoices = invoice_scope.sum("wk_invoice_items.amount")
		total_payments = payment_scope.sum("wk_payment_items.amount")

		@balance = total_invoices - total_payments
	end

	def get_inv_detail_report
		from = params[:from].presence&.to_date
		to   = params[:to].presence&.to_date
		range = getToDateTime(from)..getToDateTime(to) if from && to

		case params[:type]
		when "Invoice"
			data = { 
				graphName: l(:label_invoice),
				header: { name: l(:field_name), date: l(:label_date), amount: l(:field_amount) }
			}

			invoices = WkInvoice
				.where(invoice_date: range, invoice_type: "I")
				.order(invoice_date: :desc)

			data[:data] = invoices.map do |inv|
				amount = inv.invoice_items.sum(:amount).to_f.round(2)
				{ 
					name: inv.parent&.name, 
					date: inv.invoice_date.to_date, 
					amount: "#{inv.invoice_items.first&.currency} #{amount}" 
				}
			end

		when "Payments"
			data = { 
				graphName: l(:label_payments),
				header: { name: l(:field_name), date: l(:label_date), amount: l(:field_amount) }
			}

			payments = WkPayment
				.where(payment_date: range)
				.order(payment_date: :desc)

			data[:data] = payments.map do |pay|
				items = pay.payment_items
					.joins(:invoice)
					.where(is_deleted: false, wk_invoices: { invoice_type: "I" })

				next if items.empty?

				amount = items.sum(:amount).to_f.round(2)
				{ 
					name: pay.parent&.name, 
					date: pay.payment_date.to_date, 
					amount: "#{items.first&.currency} #{amount}" 
				}
			end.compact

		when "Balance"
			data = { 
				graphName: l(:wk_field_balance),
				header: { name: l(:field_name), balance: l(:wk_field_balance) }
			}

			invoices = WkInvoice
				.joins(:invoice_items)
				.where(invoice_type: "I")
				.group(:parent_id, :parent_type)
				.select('wk_invoices.parent_id, wk_invoices.parent_type, SUM(wk_invoice_items.amount) AS total_amount')

			payments = WkPayment
				.joins(payment_items: :invoice)
				.where(wk_payment_items: { is_deleted: false }, wk_invoices: { invoice_type: "I" })
				.group(:parent_id, :parent_type)
				.select('wk_payments.parent_id, wk_payments.parent_type, SUM(wk_payment_items.amount) AS total_amount')


			currency =  Setting.plugin_redmine_wktime['wktime_currency']

			inv_tot = invoices.each_with_object({}) do |r, h|
				next unless r.parent_id && r.parent_type
				parent_name = r.parent&.name || "N/A"
				h[[r&.parent_id, r&.parent_type, parent_name]] = r&.total_amount&.to_f
			end
			pay_tot = payments.each_with_object({}) do |r, h|
				next unless r.parent_id && r.parent_type
				parent_name = r.parent&.name || "N/A"
				h[[r&.parent_id, r&.parent_type, parent_name]] = r&.total_amount&.to_f
			end
			
			result = inv_tot.merge(pay_tot) { |_key, v1, v2| v1 - v2 }

			data[:data] = result.each_with_object([]) do |((id, type, parent_name), balance), arr|
											next if balance < 1
											arr << { name: parent_name || "N/A", balance: "#{currency} #{format('%.2f', balance)}" }
										end

		end

		render json: (data || {})
	end

	private

	def getGraphModule(path)
		Object.new.extend(("Wkdashboard::"+(File.basename(path, ".rb")).camelize).constantize)
	end
end