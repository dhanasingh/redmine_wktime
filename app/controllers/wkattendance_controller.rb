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

class WkattendanceController < WkbaseController	
	unloadable 

	menu_item :wkattendance
	include WktimeHelper
	include WkattendanceHelper
	include WkimportattendanceHelper

	before_action :require_login
	before_action :check_perm_and_redirect, :only => [:edit, :update, :clockedit]
	before_action :check_index_perm, :only => [:index]
	require 'csv' 

	def index
		sort_init 'id', 'asc'
		sort_update 'name' =>  "CONCAT(u.firstname, u.lastname)"
		@status = params[:status] || 1
		@groups = Group.all.sort
		sqlStr = ""
		lastMonthStartDt = Date.civil(Date.today.year, Date.today.month, 1) << 1
		if(Setting.plugin_redmine_wktime['wktime_leave'].blank?)
			sqlStr = " select u.id as user_id, u.firstname, u.lastname, u.status, -1 as issue_id from users u"
			if !params[:group_id].blank?
				sqlStr = sqlStr + " left join groups_users gu on u.id = gu.user_id"
			end
			sqlStr = sqlStr + " where u.type = 'User' "
		else
			listboxArr = Setting.plugin_redmine_wktime['wktime_leave'][0].split('|')
			issueId = listboxArr[0]
			sqlStr = getListQueryStr + " where u.type = 'User' and (wu.termination_date is null or wu.termination_date >= '#{lastMonthStartDt}')"
		end
		if !validateERPPermission('A_TE_PRVLG')
			sqlStr = sqlStr + " and u.id = #{User.current.id} " 
		end
		if !@status.blank?
			sqlStr = sqlStr + " and u.status = #{@status}"
		end
		if !params[:group_id].blank?
			sqlStr = sqlStr + " and gu.group_id = #{params[:group_id]}"
		end
		if !params[:name].blank?
			sqlStr = sqlStr + " and (LOWER(u.firstname) like LOWER('%#{params[:name]}%') or LOWER(u.lastname) like LOWER('%#{params[:name]}%'))"
		end
		sqlStr = sqlStr + " ORDER BY " + (sort_clause.present? ? sort_clause.first : "u.firstname")
		findBySql(sqlStr, WkUserLeave)
	end
	
	def clockindex
		sort_init 'id', 'asc'
		sort_update 'name' =>  "vw.firstname",
								'start_date'=> "entry_date",
								'clock_in'=> "cast(evw.start_time as time)",
								'clock_out'=> "cast(evw.end_time as time)",
								'hours'=> "evw.hours"
		@clk_entries = nil
		@groups = Group.sorted.all
		set_filter_session
		retrieve_date_range
		@members = Array.new
		userIds = Array.new
		userList = getGroupMembers
		userList.each do |users|
			@members << [users.name,users.id.to_s()]
			userIds << users.id
		end
		ids = nil
		user_id = session[controller_name].try(:[], :user_id)
		group_id = session[controller_name].try(:[], :group_id)
		status = session[controller_name].try(:[], :status)
		
		if user_id.blank? || !validateERPPermission('A_TE_PRVLG')
		   ids = User.current.id
		elsif user_id.to_i != 0 && group_id.to_i == 0
		   ids = user_id.to_i
		elsif group_id.to_i != 0
		   ids =user_id.to_i == 0 ? (userIds.blank? ? 0 : userIds.join(',')) : user_id.to_i
		else
		   ids = userIds.join(',')
		end
		if @from.blank? && @to.blank?
			getAllTimeRange(ids, false)
		end
		noOfDays = 't4.i*1*10000 + t3.i*1*1000 + t2.i*1*100 + t1.i*1*10 + t0.i*1'
		sqlQuery = "select vw.id as user_id, vw.firstname, vw.lastname, vw.created_on, vw.selected_date as entry_date, evw.start_time, evw.end_time, evw.hours from
			(select u.id, u.firstname, u.lastname, u.created_on, v.selected_date from" + 
			"(select " + getAddDateStr(@from, noOfDays) + " selected_date from " +
			"(select 0 i union select 1 union select 2 union select 3 union select 4 union select 5 union select 6 union select 7 union select 8 union select 9) t0,
			 (select 0 i union select 1 union select 2 union select 3 union select 4 union select 5 union select 6 union select 7 union select 8 union select 9) t1,
			 (select 0 i union select 1 union select 2 union select 3 union select 4 union select 5 union select 6 union select 7 union select 8 union select 9) t2,
			 (select 0 i union select 1 union select 2 union select 3 union select 4 union select 5 union select 6 union select 7 union select 8 union select 9) t3,
			 (select 0 i union select 1 union select 2 union select 3 union select 4 union select 5 union select 6 union select 7 union select 8 union select 9)t4)v,
			 (select u.id, u.firstname, u.lastname, u.created_on from users u where u.type = 'User' ) u
			 WHERE  v.selected_date between '#{@from}' and '#{@to}' order by u.id, v.selected_date) vw left join
			 (select min(start_time) as start_time, max(end_time) as end_time, " + getConvertDateStr('start_time') + "
			 entry_date,sum(hours) as hours, user_id from wk_attendances WHERE " + getConvertDateStr('start_time') +" between '#{@from}' and '#{@to}'			
			 group by user_id, " + getConvertDateStr('start_time') + ") evw on (vw.selected_date = evw.entry_date and vw.id = evw.user_id) where vw.id in(#{ids}) "
			 sqlQuery = sqlQuery + " ORDER BY " + (sort_clause.present? ? sort_clause.first : "vw.selected_date desc, vw.firstname")
			findBySql(sqlQuery, WkAttendance)
	end
	
	
	def clockedit
		sqlQuery = "select a.id,a.user_id, a.start_time, a.end_time, a.hours, u.firstname, u.lastname FROM users u
			left join wk_attendances a  on u.id = a.user_id and #{getConvertDateStr('a.start_time')} = '#{params[:date]}' where u.id = '#{params[:user_id]}' ORDER BY a.start_time"
		@wkattnEntries = WkAttendance.find_by_sql(sqlQuery)
	end	
	
	def getMembersbyGroup
		group_by_users=""
		userList=[]
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
	
	def set_filter_session
		session[controller_name] = {:from => @from, :to => @to} if session[controller_name].nil?
		if params[:searchlist] == controller_name
			filters = [:period_type, :period, :group_id, :user_id, :from, :to]
			filters.each do |param|
				if params[param].blank? && session[controller_name].try(:[], param).present?
					session[controller_name].delete(param)
				elsif params[param].present?
					session[controller_name][param] = params[param]
				end
			end
		end
	end
	
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
		  when 'today'
			@from = @to = Date.today
		  when 'yesterday'
			@from = @to = Date.today - 1
		  when 'current_week'
			@from = getStartDay(Date.today - (Date.today.cwday - 1)%7)
			@to = Date.today #@from + 6
		  when 'last_week'
			@from =getStartDay(Date.today - 7 - (Date.today.cwday - 1)%7)
			@to = @from + 6
		  when '7_days'
			@from = Date.today - 7
			@to = Date.today
		  when 'current_month'
			@from = Date.civil(Date.today.year, Date.today.month, 1)
			@to = Date.today #(@from >> 1) - 1
		  when 'last_month'
			@from = Date.civil(Date.today.year, Date.today.month, 1) << 1
			@to = (@from >> 1) - 1
		  when '30_days'
			@from = Date.today - 30
			@to = Date.today
		  when 'current_year'
			@from = Date.civil(Date.today.year, 1, 1)
			@to = Date.today 
		  end
		
		elsif period_type == '2' || (period_type.nil? && (!fromdate.nil? || !todate.nil?))
		  begin; @from = fromdate.to_s.to_date unless fromdate.blank?; rescue; end
		  begin; @to = todate.to_s.to_date unless todate.blank?; rescue; end
		  @free_period = true
		else				
			@from = Date.civil(Date.today.year, Date.today.month, 1)
			@to = Date.today #(@from >> 1) - 1
		end    

		@from, @to = @to, @from if @from && @to && @from > @to

	end
	
	def edit		
		sqlStr = getQueryStr + " where i.id in (#{getLeaveIssueIds}) and u.type = 'User' and u.id = #{params[:user_id]} order by i.subject"
		leavesInfo = Setting.plugin_redmine_wktime['wktime_leave']
		@accrualMultiplier = Hash.new
		if !leavesInfo.blank?
			leavesInfo.each do |leave|
				issue_id = leave.split('|')[0].strip
				@accrualMultiplier[issue_id.to_i] = leave.split('|')[5].blank? ? 1 : (leave.split('|')[5].strip).to_f
			end
		end
		@leave_details = WkUserLeave.find_by_sql(sqlStr)
		render :action => 'edit'
	end
	
	def runPeriodEndProcess
		populateWkUserLeaves(params[:fromdate].to_s.to_date)
		respond_to do |format|
			format.html {				
				flash[:notice] = l(:notice_successful_update)
				redirect_back_or_default :action => 'index', :tab => params[:tab]
			} 
		end
	end
	
	def update	
		errorMsg =nil
		wkuserleave = nil
		ids = params[:ids]
		accrualOn = params[:accrual_on]
		newIssueIds = params[:new_issue_ids]
		newIssueArr = newIssueIds.split(',')
		userId = params[:user_id]
		idArr = ids.split(',')
		idArr.each do |id|
			errorMsg =nil
			wkuserleave = nil
			wkuserleave = WkUserLeave.find(id)
			wkuserleave.balance = params["balance_"+wkuserleave.issue_id.to_s]
			wkuserleave.accrual = params["accrual_"+wkuserleave.issue_id.to_s]
			wkuserleave.used = params["used_"+wkuserleave.issue_id.to_s]
			if !wkuserleave.save()
				errorMsg = wkuserleave.errors.full_messages.join('\n')
			end
		end
		
		newIssueArr.each do |issueId|
			errorMsg =nil
			wkuserleave = nil
			wkuserleave = WkUserLeave.new
			wkuserleave.user_id = userId
			wkuserleave.issue_id = issueId
			wkuserleave.balance = params["balance_"+issueId]
			wkuserleave.accrual = params["accrual_"+issueId]
			wkuserleave.used = params["used_"+issueId]
			wkuserleave.accrual_on = accrualOn #Date.civil(Date.today.year, Date.today.month, 1) -1
			if !wkuserleave.save()
				errorMsg = wkuserleave.errors.full_messages.join('\n')
			end
		end
		
		if errorMsg.nil?	
			redirect_to :controller => 'wkattendance',:action => 'index' , :tab => 'wkattendance'
			flash[:notice] = l(:notice_successful_update)
		else
			flash[:error] = errorMsg
			redirect_to :action => 'edit'
		end		
	end
	
	def getQueryStr
		queryStr = ''
		accrualOn = params[:accrual_on].blank? ? Date.civil(Date.today.year, Date.today.month, 1) -1 : params[:accrual_on].to_s.to_date
		queryStr = "select u.id as user_id, u.firstname, u.lastname, i.id as issue_id,w.balance, w.accrual, w.used, w.accrual_on, w.id from users u " +
			"left join wk_users wu on u.id = wu.user_id " +
			"cross join issues i left join wk_user_leaves w on w.user_id = u.id and w.issue_id = i.id
			and w.accrual_on = '#{accrualOn}' "
		queryStr
	end
	
	def getListQueryStr
		accrualOn = params[:accrual_on].blank? ? Date.civil(Date.today.year, Date.today.month, 1) -1 : params[:accrual_on].to_s.to_date
		selectColStr = "select u.id as user_id, u.firstname, u.lastname, u.status"
		joinTableStr = ""
		Setting.plugin_redmine_wktime['wktime_leave'].each_with_index do |element,index|
			if index < 5
				tAlias = "w#{index.to_s}"
				listboxArr = element.split('|')
				joinTableStr = joinTableStr + " left join wk_user_leaves #{tAlias} on #{tAlias}.user_id = u.id and #{tAlias}.issue_id = " + listboxArr[0] + " and #{tAlias}.accrual_on = '#{accrualOn}'"
				selectColStr = selectColStr + ", (#{tAlias}.balance + #{tAlias}.accrual - #{tAlias}.used) as total#{index.to_s}"
			end
		end
		queryStr = selectColStr + " from users u left join wk_users wu on u.id = wu.user_id " + joinTableStr 
		
		if !params[:group_id].blank?
			queryStr = queryStr + " left join groups_users gu on u.id = gu.user_id"
		end
		queryStr
	end
	
	def getIssuesByProject
		issue_by_project=""
		issueList=[]				
		issueList = getPrjIssues
		issueList.each do |issue|
			issue_by_project << issue.id.to_s() + ',' + issue.subject + "\n"
		end
		respond_to do |format|
			format.text  { render :plain => issue_by_project }
		end
	end	
	
	def getPrjIssues
		issueList = []
		project_id = 0
		project = nil		
		if !params[:project_id].blank?
			project_id = params[:project_id]
			project = Project.find(project_id)
		end
		if ((!project.blank? && (project.status == Project::STATUS_CLOSED || project.status == Project::STATUS_ARCHIVED)) && !params[:issue_id].blank?)
			issueList = Issue.where(:id => params[:issue_id], :project_id => project_id)
		else
			issueList = Issue.where(:project_id => project_id)
		end
		issueList
	end
	
    def check_perm_and_redirect
	  unless check_permission
	    render_403
	    return false
	  end
    end

	def check_permission
		ret = false
		ret = params[:user_id].to_i == User.current.id
		return (ret || validateERPPermission('A_TE_PRVLG'))
	end
	
	def getProjectByIssue
		project_id=""
		project_by_issue=""
		if !params[:issue_id].blank?
			issue_id = params[:issue_id]
			issues = Issue.where(:id => issue_id.to_i)
			project_id = issues[0].project_id
			project_by_issue = issues[0].project_id.to_s + '|' + issues[0].project.name 
		end
		respond_to do |format|
			format.text  { render :plain => project_by_issue }
		end
	end

	def setLimitAndOffset		
		if api_request?
			@offset, @limit = api_offset_and_limit
			if !params[:limit].blank?
				@limit = params[:limit]
			end
			if !params[:offset].blank?
				@offset = params[:offset]
			end
		else
			@entry_pages = Paginator.new @entry_count, per_page_option, params['page']
			@limit = @entry_pages.per_page
			@offset = @entry_pages.offset
		end	
	end
	
	def findBySql(query, model)
		result = model.find_by_sql("select count(*) as id from (" + query + ") as v2")
		@entry_count = result.blank? ? 0 : result[0].id
        setLimitAndOffset()		
		rangeStr = formPaginationCondition()		
		if model == WkUserLeave
			@leave_entries = model.find_by_sql(query + rangeStr )
		else
			@clk_entries = model.find_by_sql(query + rangeStr )
		end
	end
	
	def formPaginationCondition
		rangeStr = ""
		if ActiveRecord::Base.connection.adapter_name == 'SQLServer'				
			rangeStr = " OFFSET " + @offset.to_s + " ROWS FETCH NEXT " + @limit.to_s + " ROWS ONLY "
		else		
			rangeStr = " LIMIT " + @limit.to_s +	" OFFSET " + @offset.to_s
		end
		rangeStr
	end
	
	def saveClockInOut
		errorMsg =nil
		sucessMsg = nil
		endtime = nil
		for i in 0..params[:attnDayEntriesCnt].to_i-1
			starttime = params[:startdate] + " " +  params["attnstarttime#{i}"] + ":00"
			entry_start_time = DateTime.strptime(starttime, "%Y-%m-%d %T") rescue starttime
			endtime = params[:startdate] + " " +  params["attnendtime#{i}"] + ":00" if !params["attnendtime#{i}"].blank?
			entry_end_time = DateTime.strptime(endtime, "%Y-%m-%d %T") rescue endtime
			if params["attnstarttime#{i}"] == '0:00' && params["attnendtime#{i}"] == '0:00' 
				wkattendance =  WkAttendance.find(params["attnEntriesId#{i}"].to_i)	if !params["attnEntriesId#{i}"].blank?
				wkattendance.destroy()
				sucessMsg = l(:notice_successful_delete)
			else
				if !params["attnEntriesId#{i}"].blank?
					wkattendance =  WkAttendance.find(params["attnEntriesId#{i}"].to_i)				
					wkattendance.start_time =  getFormatedTimeEntry(entry_start_time)
					wkattendance.end_time = getFormatedTimeEntry(entry_end_time) #if !entry_end_time.blank?
					wkattendance.hours = computeWorkedHours(wkattendance.start_time, wkattendance.end_time, true) if !wkattendance.end_time.blank?
					wkattendance.save()
					sucessMsg = l(:notice_successful_update) 				
				else
					addNewAttendance(getFormatedTimeEntry(entry_start_time),getFormatedTimeEntry(entry_end_time), params[:user_id].to_i)
					sucessMsg = l(:notice_successful_update)
				end			
			end
		end
		
		if errorMsg.nil?	
			redirect_to :controller => 'wkattendance',:action => 'clockindex' , :tab => 'clock'
			flash[:notice] = sucessMsg 
		else
			flash[:error] = errorMsg
			redirect_to :action => 'edit'
		end	
	end

	def check_index_perm
		redirect = set_attendance_module
		if !showAttendance && redirect.blank?
			render_403
		elsif !showAttendance
			redirect_to redirect
		end

	end
end
