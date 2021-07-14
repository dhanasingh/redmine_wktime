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
	accept_api_auth :getGraphs
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

	def graph(path="")
		path = params[:gPath] if params[:gPath].present?
		data = nil
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
			return(data || {})
		else
			render(json: (data || {}))
		end
	end

	def getDataSet
		path = params[:gPath] if params[:gPath].present?
		data = nil
		group_id = session[controller_name].try(:[], :group_id)
		project_id = session[controller_name].try(:[], :project_id)
		setDateRange

		begin
			load(path)
			obj = Object.new.extend(WkDashboard)
			data = obj.dataset({from: @from, to: @to, group_id: group_id, project_id: project_id})
		rescue
			data = {error: "404"}
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
		graphs = get_graphs_yaml_path().sort
		graphDetails = []
		graphs.each{ |path| graphDetails << graph(path) }
		render json: {graphs: graphDetails, unseen_count: @unseen_count}
	end
end