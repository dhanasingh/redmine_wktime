# ERPmine - ERP for service industry
# Copyright (C) 2011-2016  Adhi software pvt ltd
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

class WkreportController < WkbaseController


include WktimeHelper
include WkreportHelper
include WkattendanceHelper
include WkpayrollHelper
include WkaccountingHelper
include WkcrmHelper

before_action :require_login
before_action :check_perm_and_redirect

accept_api_auth :get_reports, :get_report_data, :export

	def index
		@groups = Group.sorted.all
		set_filter_session
		retrieve_date_range
		@members = Array.new
		userList = get_group_members
		userList.each do |users|
			@members << [users.name,users.id.to_s()]
		end
		showReport
	end

	def showReport
		if params[:report_type] == 'report_time'
			redirect_to action: 'time_rpt', controller: 'wktime'
		elsif params[:report_type] == 'report_expense'
			redirect_to :action => 'time_rpt', :controller => 'wkexpense'
		elsif !params[:report_type].blank?
			@reportType = params[:report_type]
			render :action => 'report', :layout => false
		end
	end

	def set_filter_session
		filters = [:report_type, :period_type, :period, :from, :to, :group_id, :project_id, :user_id]
		super(filters, {:from => @from, :to => @to, user_id: User.current.id})
	end

	def get_membersby_group
		group_by_users=""
		userList=[]
		#set_managed_projects
		userList = get_group_members
		userList.each do |users|
			group_by_users << users.id.to_s() + ',' + users.name + "\n"
		end
		respond_to do |format|
			format.text  { render :plain => group_by_users }
		end
	end

	def get_group_members
		userList = nil
		group_id = nil
		if (!params[:group_id].blank?)
			group_id = params[:group_id]
		else
			group_id = session[controller_name].try(:[], :group_id)
		end

		if !group_id.blank? && group_id.to_i > 0
			userList = User.in_group(group_id)
		else
			userList = User.order("#{User.table_name}.firstname ASC,#{User.table_name}.lastname ASC")
		end
		userList
	end

	def get_reports
		headers = {}
		reportType = getReportType(true)
		projects = Project.active.order('name')
		groups = Group.sorted.givable
		headers[:projects] = projects.map{ |p| [p.name, p.id]}
		headers[:groups] = groups.map{ |g| [g.name, g.id]}
		render json: {wk_reports: reportType, headers: headers}
	end

	def get_report_data
		user_id = params[:user_id] || User.current.id
		group_id = params[:group_id] || "0"
		projId = params[:project_id] || "0"
		from = params[:from].to_date || Date.today.beginning_of_month
		to = params[:to].to_date || Date.today.end_of_month
		attachment = WkLocation.getMainLogo
		base64Image = getBase64Image(attachment)
		if(params[:report_type].present?)
			require_relative "../views/wkreport/#{params[:report_type]}"
			report = Object.new.extend(params[:report_type].camelize.constantize)
			reportData = report.calcReportData(user_id, group_id, projId, from, to)
		end
		reportDetails = { reportData: reportData, location: getMainLocation, address: getAddress, logo: base64Image }
		render json: reportDetails
	end

	def export
		set_filter_session
		retrieve_date_range
		report_type = params[:report_type]
		if report_type.present?
			report_type.slice!("_web") if report_type.include? "_web"
			begin
				require_relative "../views/wkreport/#{report_type}"
			rescue LoadError
				puts "#{report_type} file was not found"
				return nil
			end
			report = Object.new.extend(report_type.camelize.constantize)
			reportData = report.getExportData(getSession(:user_id) || User.current.id, getSession(:group_id).to_i, getSession(:project_id), @from, @to)
			pdf = report.pdf_export(**reportData, location: getMainLocation, from: @from, to: @to, logo: WkLocation.getMainLogo)
			csv = reportData[:customize].blank? ? csv_export(reportData) : report.csv_export(reportData)
		end

		respond_to do |format|
			format.csv do
				send_data(csv, type: 'text/csv', filename: "#{report_type}.csv")
			end
			format.pdf do
				send_data(pdf, :type => 'application/pdf', :filename => "#{report_type}.pdf")
			end
		end
	end

	private

	# Retrieves the date range based on predefined ranges or specific from/to param dates
	def retrieve_date_range
		@free_period = false
		@from, @to = nil, nil
		period_type = session[controller_name].try(:[], :period_type)
		period = session[controller_name].try(:[], :period)
		fromdate = session[controller_name].try(:[], :from)
		todate = session[controller_name].try(:[], :to)

		if (period_type == '1' || (period_type.nil? && !period.nil?))
		  case period.to_s
		  when 'current_month'
			@from = Date.civil(Date.today.year, Date.today.month, 1)
			@to = (@from >> 1) - 1
		  when 'last_month'
			@from = Date.civil(Date.today.year, Date.today.month, 1) << 1
			@to = (@from >> 1) - 1
		  when 'current_week'
			@from = getStartDay(Date.today - (Date.today.cwday - 1)%7)
			@to = @from + 6
		  when 'last_week'
			@from =getStartDay(Date.today - 7 - (Date.today.cwday - 1)%7)
			@to = @from + 6
		  end
		elsif period_type == '2' || (period_type.nil? && (!fromdate.nil? || !todate.nil?))
		  begin; @from = fromdate.to_s.to_date unless fromdate.blank?; rescue; end
		  begin; @to = todate.to_s.to_date unless todate.blank?; rescue; end
		  if @from.blank?
			@from = Date.civil(Date.today.year, Date.today.month, 1)
			@to = (@from >> 1) - 1
		  end
		  @free_period = true
		else
			@from = Date.civil(Date.today.year, Date.today.month, 1)
			@to = (@from >> 1) - 1
		end
		session[controller_name][:from] = @from
		session[controller_name][:to] = @to
		@from, @to = @to, @from if @from && @to && @from > @to

	end

	def check_perm_and_redirect
		unless validateERPPermission("V_REPORT")
			render_403
			return false
		end
	end

	def pdf_export(data)
		pdf = super
		row_Height = 8
		page_width    = pdf.get_page_width
		left_margin   = pdf.get_original_margins['left']
		right_margin  = pdf.get_original_margins['right']
		table_width = page_width - right_margin - left_margin
		width = table_width/data[:headers].length
		pdf.ln
		pdf.SetFontStyle('B', 9)
		pdf.set_fill_color(230, 230, 230)
		data[:headers].each{ |key, value| pdf.RDMCell(width, row_Height, value.to_s, 1, 0, '', 1) }
		pdf.ln
		pdf.set_fill_color(255, 255, 255)

		pdf.SetFontStyle('', 8)
		data[:data].each do |entry|
			entry.each{ |key, value| pdf.RDMCell(width, row_Height, value.to_s, 1, 0, '', 0) }
		pdf.ln
		end
		pdf.Output
	end
end
