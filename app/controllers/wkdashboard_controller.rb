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
	accept_api_auth :getGraphs, :getDetailReport
	include WkdashboardHelper
	include WkcrmHelper
	include WktimeHelper
	include WkpayrollHelper

	def index
		if !showDashboard || !hasSettingPerm
			redirect_to set_module
		else
			set_filter_session
			setMembers
			retrieve_date_range
		end
	end

	def graph(path=params[:gPath])
		data = {}
		group_id = session[controller_name].try(:[], :group_id)
		project_id = session[controller_name].try(:[], :project_id)
		setDateRange

		begin
			load(path)
			obj = Object.new.extend(WkDashboard)
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

	def getDetailReport
		if params[:dashboard_type] != "Emp"
			path = params[:gPath] if params[:gPath].present?
			data = nil
			group_id = session[controller_name].try(:[], :group_id)
			project_id = session[controller_name].try(:[], :project_id)
			setDateRange

			begin
				load(path)
				obj = Object.new.extend(WkDashboard)
				data = obj.getDetailReport({from: @from, to: @to, group_id: group_id, project_id: project_id})
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
		filters = [:project_id, :group_id, :period, :from, :to]
		super(filters)
	end

	def setMembers
		@groups = Group.where(type: "Group").sorted.all
	end

	def getGraphs
		graphDetails = params[:dashboard_type] == "Emp" ? getEmpDashboard() : (get_graphs_yaml_path.sort).map{|path| graph(path)}
		render json: {graphs: graphDetails, unseen_count: @unseen_count}
	end

	def getEmpDashboard
		data = []
		if showAttendance
			leaves = WkUserLeave.leaveCounts.map{|l| {name: l.subject, value: l.leave_count, issue_id: l.issue_id, type: "leave"}}
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
end