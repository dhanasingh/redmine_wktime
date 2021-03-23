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

require_relative '../views/wkreport/report_payslip'
class WkreportController < WkbaseController	
unloadable 

include WktimeHelper
include WkreportHelper
include WkattendanceHelper
include WkpayrollHelper
include WkaccountingHelper
include WkcrmHelper
include PayslipReport

before_action :require_login
before_action :check_perm_and_redirect

accept_api_auth :get_report_type, :get_projects, :getReportEntries
	
	def index
		@groups = Group.sorted.all
		set_filter_session
		retrieve_date_range
		@members = Array.new
		userList = getGroupMembers
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
		super(filters, {:from => @from, :to => @to})
	end
	
	def getMembersbyGroup
		group_by_users=""
		userList=[]
		#set_managed_projects				
		userList = getGroupMembers
		userList.each do |users|
			group_by_users << users.id.to_s() + ',' + users.name + "\n"
		end
		respond_to do |format|
			format.text  { render :plain => group_by_users }
		end
	end	
	
	def getGroupMembers
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
	
	def get_report_type
		reportType = getReportType(true)
		render json: reportType
	end
	
	def get_projects
		projects = Project.where("#{Project.table_name}.status not in(#{Project::STATUS_CLOSED},#{Project::STATUS_ARCHIVED})").order('name')
		projArr = projects.map { |proj| { value: proj.id, label: proj.name }}
		render json: projArr
	end
	
	def getReportEntries
		user_id = params[:user_id] || User.current.id
		group_id = params[:group_id] || '0'
		case(params[:report_type])
		when 'report_payslip'
			reportEntries = getPayslip(user_id, params[:from], params[:to])
		end
		render json: reportEntries
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
end
