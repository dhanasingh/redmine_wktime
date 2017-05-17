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
unloadable 

include WktimeHelper
include WkreportHelper
include WkattendanceHelper
include WkpayrollHelper
include WkaccountingHelper
include WkcrmHelper

before_filter :require_login
# before_filter :check_perm_and_redirect, :only => [:index]
	
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
		#report #patched method
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
		if params[:searchlist].blank? && session[:wkreport].nil?
			session[:wkreport] = {:report_type => params[:report_type], :period_type => params[:period_type], :period => params[:period],:group_id => params[:group_id], :user_id => params[:user_id], :from => @from, :to => @to, :project_id => params[:project_id] }
		elsif params[:searchlist] =='wkreport'
			session[:wkreport][:report_type] = params[:report_type]
			session[:wkreport][:period_type] = params[:period_type]
			session[:wkreport][:period] = params[:period]
			session[:wkreport][:group_id] = params[:group_id]
			session[:wkreport][:user_id] = params[:user_id]
			session[:wkreport][:from] = params[:from]
			session[:wkreport][:to] = params[:to].blank? ? Date.today : params[:to]
			session[:wkreport][:project_id] = params[:project_id]
		end
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
			format.text  { render :text => group_by_users }
		end
	end	
	
	def getGroupMembers
		userList = nil
		group_id = nil
		if (!params[:group_id].blank?)
			group_id = params[:group_id]
		else
			group_id = session[:wkreport][:group_id]
		end
		
		if !group_id.blank? && group_id.to_i > 0
			userList = User.in_group(group_id) 
		else
			userList = User.order("#{User.table_name}.firstname ASC,#{User.table_name}.lastname ASC")
		end
		userList
	end
	
	private	
	
	# Retrieves the date range based on predefined ranges or specific from/to param dates
	  def retrieve_date_range
		@free_period = false
		@from, @to = nil, nil
		period_type = session[:wkreport][:period_type]
		period = session[:wkreport][:period]
		fromdate = session[:wkreport][:from]
		todate = session[:wkreport][:to]

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
		  # default
		  # 'current_month'		
			@from = Date.civil(Date.today.year, Date.today.month, 1)
			@to = (@from >> 1) - 1
		end    
		session[:wkreport][:from] = @from
		session[:wkreport][:to] = @to
		@from, @to = @to, @from if @from && @to && @from > @to

	  end
	
    # def check_perm_and_redirect
	  # unless check_permission
	    # render_403
	    # return false
	  # end
    # end

	# def check_permission
		# if params[:report_type] == 'pl_rpt' || params[:report_type] == 'balance_sheet'
			# ret = isModuleAdmin('wktime_accounting_group') || isModuleAdmin('wktime_accounting_admin')
		# elsif params[:report_type] == 'lead_conv_rpt' || params[:report_type] == 'sales_act_rpt'
			# ret = isModuleAdmin('wktime_crm_group') || isModuleAdmin('wktime_crm_admin') 
		# else
			# ret = params[:user_id].to_i == User.current.id
			# ret = (ret || isAccountUser || User.current.admin?)
		# end
		# ret = true if params[:report_type].blank?
		# ret
	# end	
	
end
