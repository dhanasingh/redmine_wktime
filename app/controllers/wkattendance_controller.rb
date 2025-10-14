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

class WkattendanceController < WkbaseController


	menu_item :wkattendance
	include WktimeHelper
	include WkattendanceHelper
	include WkimportattendanceHelper

	before_action :require_login
	before_action :check_perm_and_redirect, :only => [:edit, :clockedit]
	before_action :check_update_permission, :only => [:update, :save_clock_in_out]
	before_action :check_index_perm, :only => [:index]
	require 'csv'

	accept_api_auth :clockindex, :clockedit, :save_clock_in_out, :get_clock_hours, :index, :edit, :update

	def index
		sort_init 'id', 'asc'
		sort_update 'name' =>  "CONCAT(u.firstname, u.lastname)"
		set_filter_session([:status, :group_id, :name])
		@status = getSession(:status) || 1
		@groups = Group.where(type: "Group").all.sort
		sqlStr = ""
		lastMonthStartDt = Date.civil(Date.today.year, Date.today.month, 1) << 1
		if(getLeaveSettings.blank?)
			selectStr = " select u.id as user_id, u.firstname, u.lastname, u.status, -1 as issue_id "
			sqlStr = " from users u"
			sqlStr = sqlStr + " left join groups_users gu on u.id = gu.user_id " if getSession(:group_id).present?
			sqlStr = sqlStr + " where u.type = 'User' " + get_comp_condition('u')
		else
			listboxArr = getLeaveSettings[0].split('|')
			issueId = listboxArr[0]
			queries = getListQueryStr
			selectStr = queries[0]
			sqlStr = queries[1] + " where u.type = 'User' and (wu.termination_date is null or wu.termination_date >= '#{lastMonthStartDt}') " + get_comp_condition('u')
		end
		if !validateERPPermission('A_ATTEND')
			sqlStr = sqlStr + " and u.id = #{User.current.id} "
		end
		if @status.present? && @status != "0"
			sqlStr = sqlStr + " and u.status = #{@status}"
		end
		if !getSession(:group_id).blank?
			sqlStr = sqlStr + " and gu.group_id = #{getSession(:group_id)}"
		end
		if !getSession(:name).blank?
			sqlStr = sqlStr + " and (LOWER(u.firstname) like LOWER('%#{getSession(:name)}%') or LOWER(u.lastname) like LOWER('%#{getSession(:name)}%'))"
		end
		orderStr = " ORDER BY " + (sort_clause.present? ? sort_clause.first : "u.firstname")

		respond_to do |format|
			format.html do
				findBySql(selectStr, sqlStr, orderStr, WkUserLeave)
				render :layout => !request.xhr?
			end
			format.api do
				@leave_entries = WkUserLeave.find_by_sql(selectStr + sqlStr + orderStr)
			end
      format.csv do
				headers = {user: l(:field_user)}
				entries = WkUserLeave.find_by_sql(selectStr + sqlStr + orderStr)
				data = []
				entries.each_with_index do |e, index|
					dataCol = {user: e.user&.name}
					(getLeaveSettings || []).first(5).each_with_index do |l, colIndx|
						if index == 0
							leave = Issue.where(id: l.split("|").first).first&.subject
							headers[leave] = leave if leave.present?
						end
						dataCol['total'+index.to_s+colIndx.to_s] = (e['total'+colIndx.to_s] || 0).round(2)
					end
					data << dataCol
				end
        send_data(csv_export(headers: headers, data: data), type: "text/csv; header=present", filename: "userleave.csv")
      end
		end
	end

	def clockindex
		sort_init 'id', 'asc'
		sort_update 'name' =>  "vw.firstname",
								'start_date'=> "entry_date",
								'clock_in'=> "cast(evw.start_time as time)",
								'clock_out'=> "cast(evw.end_time as time)",
								'hours'=> "evw.hours"
		@clk_entries = nil
		@groups = Group.where(type: "Group").sorted.all
		set_filter_session([:period_type, :period, :group_id, :user_id, :from, :to, :show_on_map], {:from => @from, :to => @to})
		retrieve_date_range
		@members = Array.new
		userIds = Array.new
		userList = get_group_members
		userList.each do |users|
			@members << [users.name,users.id.to_s()]
			userIds << users.id
		end
		ids = nil
		user_id = session[controller_name].try(:[], :user_id)
		group_id = session[controller_name].try(:[], :group_id)
		status = session[controller_name].try(:[], :status)

		if user_id.blank? || !validateERPPermission('A_ATTEND')
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
		selectStr = "select evw.id, vw.id as user_id, vw.firstname, vw.lastname, vw.created_on, vw.selected_date as entry_date, evw.start_time, evw.end_time, evw.hours,
				s_longitude, s_latitude, e_longitude, e_latitude "
		sqlQuery = " from (
			select u.id, u.firstname, u.lastname, u.created_on, v.selected_date from" +
			"(select " + getAddDateStr(@from, noOfDays) + " selected_date from " +
			"(select 0 i union all select 1 union all select 2 union all select 3 union all select 4 union all select 5 union all select 6 union all select 7 union all select 8 union all select 9) t0,
			(select 0 i union all select 1 union all select 2 union all select 3 union all select 4 union all select 5 union all select 6 union all select 7 union all select 8 union all select 9) t1,
			(select 0 i union all select 1 union all select 2 union all select 3 union all select 4 union all select 5 union all select 6 union all select 7 union all select 8 union all select 9) t2,
			(select 0 i union all select 1 union all select 2 union all select 3 union all select 4 union all select 5 union all select 6 union all select 7 union all select 8 union all select 9) t3,
			(select 0 i union all select 1 union all select 2 union all select 3 union all select 4 union all select 5 union all select 6 union all select 7 union all select 8 union all select 9)t4)v,
			(select u.id, u.firstname, u.lastname, u.created_on from users u where u.type = 'User' #{get_comp_condition('u')}) u
			WHERE  v.selected_date between '#{@from}' and '#{@to}' AND u.id in (#{ids})) vw
			left join(
				 select id, start_time, end_time, " + getConvertDateStr('start_time') + " entry_date, hours, user_id, s_longitude, s_latitude, e_longitude, e_latitude
				 from wk_attendances
				 WHERE " + getConvertDateStr('start_time') +" between '#{@from}' and '#{@to}' AND user_id in (#{ids}) #{get_comp_condition('wk_attendances')}
			) evw on (vw.selected_date = evw.entry_date and vw.id = evw.user_id) where vw.id in (#{ids}) AND vw.selected_date <= '#{Time.now.to_date}'"
		orderStr = " ORDER BY " + (sort_clause.present? ? sort_clause.first : "vw.selected_date desc, vw.firstname")

		respond_to do |format|
			format.html do
				findBySql(selectStr, sqlQuery, orderStr, WkAttendance)
				render :layout => !request.xhr?
			end
			format.api do
				@clk_entries = WkAttendance.find_by_sql(selectStr + sqlQuery + orderStr)
			end
			format.csv do
				entries = WkAttendance.find_by_sql(selectStr + sqlQuery + orderStr)
				headers = {user: l(:field_user), date: l(:field_start_date), clockin: l(:label_clock_in), clockout: l(:label_clock_in), hours: l(:field_hours) }
				data = entries.map{|e|
					{user: e&.user&.name, date: e&.entry_date&.to_date, startDate: e&.start_time&.localtime&.strftime('%R'),
					endDate: e&.end_time&.localtime&.strftime('%R'), hours: e&.hours ? (e&.hours).round(2) : ""}
				}
				send_data(csv_export(headers: headers, data: data), type: "text/csv; header=present", filename: "clock.csv")
			end
		end
	end

	def clockedit
		sqlQuery = "select a.id,a.user_id, a.start_time, a.end_time, a.hours, u.firstname, u.lastname, s_longitude, s_latitude, e_longitude, e_latitude
			FROM users u
			left join wk_attendances a  on u.id = a.user_id and #{getConvertDateStr('a.start_time')} = '#{params[:date].to_date}' #{get_comp_condition('a')}
			where u.id = '#{params[:user_id]}' #{get_comp_condition('u')} ORDER BY a.start_time"
		@wkattnEntries = WkAttendance.find_by_sql(sqlQuery)
		respond_to do |format|
			format.html {
				render :layout => !request.xhr?
			}
			format.api
		end
	end

	def get_membersby_group
		group_by_users=""
		userList=[]
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
			userList = User.where(type: "User").order("#{User.table_name}.firstname ASC,#{User.table_name}.lastname ASC")
		end
		userList
	end

	def set_filter_session(filters, param={})
		super(filters, param)
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
		leavesInfo = getLeaveSettings
		@accrualMultiplier = Hash.new
		if !leavesInfo.blank?
			leavesInfo.each do |leave|
				issue_id = leave.split('|')[0].strip
				@accrualMultiplier[issue_id.to_i] = leave.split('|')[5].blank? ? 1 : (leave.split('|')[5].strip).to_f
			end
		end
		@leave_details = WkUserLeave.find_by_sql(sqlStr)
		respond_to do |format|
			format.html {
				render :layout => !request.xhr?
			}
			format.api
		end
	end

	def run_period_end_process
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

    respond_to do |format|
      format.html {
        if errorMsg.nil?
          redirect_to :controller => 'wkattendance',:action => 'index' , :tab => 'leave'
          flash[:notice] = l(:notice_successful_update)
        else
          flash[:error] = errorMsg
          redirect_to action: 'edit'
        end
      }
      format.api{
        if errorMsg.blank?
          render :plain => errorMsg, :layout => nil
        else
          @error_messages = errorMsg.split('\n')
          render :template => 'common/error_messages', :format => [:api], :status => :unprocessable_entity, :layout => nil
        end
      }
    end
	end

	def getQueryStr
		queryStr = ''
		accrualOn = params[:accrual_on].blank? ? Date.civil(Date.today.year, Date.today.month, 1) -1 : params[:accrual_on].to_s.to_date
		queryStr = "select u.id as user_id, u.firstname, u.lastname, i.id as issue_id,w.balance, w.accrual, w.used, w.accrual_on, w.id
			from users u " +
			"left join wk_users wu on u.id = wu.user_id " + get_comp_condition('wu') +
			"cross join issues i
			left join wk_user_leaves w on w.user_id = u.id and w.issue_id = i.id and w.accrual_on = '#{accrualOn}' " + get_comp_condition('i') +
			get_comp_condition('w')
		queryStr
	end

	def getListQueryStr
		accrualOn = params[:accrual_on].blank? ? Date.civil(Date.today.year, Date.today.month, 1) -1 : params[:accrual_on].to_s.to_date
		selectColStr = "select u.id as user_id, u.firstname, u.lastname, u.status"
		joinTableStr = ""
		getLeaveSettings.each_with_index do |element,index|
			if index < 5
				tAlias = "w#{index.to_s}"
				listboxArr = element.split('|')
				joinTableStr = joinTableStr + " left join wk_user_leaves #{tAlias} on #{tAlias}.user_id = u.id and #{tAlias}.issue_id = " + listboxArr[0] + " and #{tAlias}.accrual_on = '#{accrualOn}' " + get_comp_condition("#{tAlias}")
				selectColStr = selectColStr + ", (#{tAlias}.balance + #{tAlias}.accrual - #{tAlias}.used) as total#{index.to_s}"
			end
		end
		queryStr = " from users u left join wk_users wu on u.id = wu.user_id " + get_comp_condition('wu') + joinTableStr

		if getSession(:group_id).present?
			queryStr = queryStr + " left join groups_users gu on u.id = gu.user_id"
		end
		return [selectColStr, queryStr]
	end

	def get_issues_by_project
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
		return (ret || validateERPPermission('A_ATTEND'))
	end

	def check_update_permission
		unless validateERPPermission('A_ATTEND') && params[:user_id].to_i != User.current.id
			render_403
			return false
		end
	end

	def get_project_by_issue
		project_id = ""
		project_by_issue=""
		if !params[:issue_id].blank?
			issue_id = params[:issue_id]
			issues = Issue.where(:id => issue_id.to_i)
			project_id = issues[0].project_id
			project_by_issue = project_id.to_s + '|' + issues[0].project.name
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

	def findBySql(selectStr, query, orderStr, model)
		@entry_count = findCountBySql(query, model)
    setLimitAndOffset()
		rangeStr = formPaginationCondition()
		if model == WkUserLeave
			@leave_entries = model.find_by_sql(selectStr + query + orderStr + rangeStr)
		else
			@clk_entries = model.find_by_sql(selectStr + query + orderStr + rangeStr)
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

	def save_clock_in_out
		endtime = nil
		errorMsg = []
		if api_request?
			params['clock_entries'].each do |cEntries|
				# starttime = params[:startdate].to_date.to_s + " " +  cEntries['clock_in'] + ":00"
				# entry_start_time = DateTime.strptime(cEntries['clock_in'], "%Y-%m-%d %T") rescue starttime
				# endtime = params[:startdate].to_date.to_s + " " +  cEntries['clock_out'] + ":00" if !cEntries['clock_out'].blank?
				# entry_end_time = DateTime.strptime(cEntries['clock_out'], "%Y-%m-%d %T") rescue endtime
				if !cEntries['id'].blank?
					err = updateClockInOutEntry(cEntries['id'], cEntries['clock_in'], cEntries['clock_out'])
					if err.respond_to?(:errors) && err.errors.any?
						errorMsg << err.errors.full_messages.join(", ")
					end
				else
					err = addNewAttendance(cEntries['clock_in'], cEntries['clock_out'], params[:user_id].to_i)
					if err.respond_to?(:errors) && err.errors.any?
						errorMsg << err.errors.full_messages.join(", ")
					end
				end
			end
		else

			sucessMsg = nil
			endtime = nil
			for i in 0..params[:attnDayEntriesCnt].to_i-1
				starttime = params[:startdate].to_date.to_s + " " +  params["attnstarttime#{i}"] + ":00"
				entry_start_time = DateTime.strptime(starttime, "%Y-%m-%d %T") rescue starttime
				endtime = params[:startdate].to_date.to_s + " " +  params["attnendtime#{i}"] + ":00" if !params["attnendtime#{i}"].blank?
				entry_end_time = DateTime.strptime(endtime, "%Y-%m-%d %T") rescue endtime
				if (params["attnstarttime#{i}"] == '00:00' || params["attnstarttime#{i}"] == '0:00') && (params["attnendtime#{i}"] == '00:00' || params["attnendtime#{i}"] == '0:00')
					wkattendance =  WkAttendance.find(params["attnEntriesId#{i}"].to_i)	if !params["attnEntriesId#{i}"].blank?
					wkattendance.destroy()
					sucessMsg = l(:notice_successful_delete)
				else
					if !params["attnEntriesId#{i}"].blank?
						updateClockInOutEntry(params["attnEntriesId#{i}"], getFormatedTimeEntry(entry_start_time), getFormatedTimeEntry(entry_end_time))
						sucessMsg = l(:notice_successful_update)
					else
						wkattendance = addNewAttendance(getFormatedTimeEntry(entry_start_time),getFormatedTimeEntry(entry_end_time), params[:user_id].to_i)

						if wkattendance.id.present?
							sucessMsg = l(:notice_successful_update)
						else
            	errorMsg << wkattendance.errors.full_messages.join(", ")
            end
					end
				end
			end
		end
    errorMsg = errorMsg.join(", ")

		respond_to do |format|
			format.html {
			if errorMsg.blank?
				redirect_to controller: 'wkattendance', action: 'clockindex', page: params[:page], tab: 'clock'
				flash[:notice] = sucessMsg
			else
				flash[:error] = errorMsg
				redirect_to :action => 'clockindex'
			end
		}
		format.api{
		if errorMsg.blank?
			render :plain => errorMsg, :layout => nil
		else
			@error_messages = errorMsg.split('\n')
			render :template => 'common/error_messages', :format => [:api], :status => :unprocessable_entity, :layout => nil
		end
		}
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

	def save_bulk_edit
		err_msg = ''
		params.each do |param, val|
			splits = param.split("_")
			key = "#{splits[1].to_s}_#{splits[2].to_s}"
			attnd_id = splits[1]
			if ["clockin_" + key].include?(param) && val.present? && (params["h_clockin_" + key] != val ||
					params["clockout_" + key] != params["h_clockout_" + key])
				start_time = params["startdate_" + key].to_date.to_s + " " +  params["clockin_" + key] + ":00"
				start_time = DateTime.strptime(start_time, "%Y-%m-%d %T") rescue start_time
				end_time = params["startdate_" + key].to_date.to_s + " " +  params["clockout_" + key] + ":00" if params["clockout_" + key].present?
				end_time = DateTime.strptime(end_time, "%Y-%m-%d %T") rescue end_time
				startTime = getFormatedTimeEntry(start_time)
				endTime = getFormatedTimeEntry(end_time)
				begin
					if (params["clockin_" + key] == '0:00' || params["clockin_" + key] == '00:00') && (params["clockout_" + key] == '0:00' || params["clockout_" + key] == '00:00') && attnd_id.present?
						wkattendance =  WkAttendance.find(attnd_id.to_i)
						wkattendance.destroy()
					elsif attnd_id.present?
						wkattendance = updateClockInOutEntry(attnd_id, startTime, endTime)
					else
						wkattendance = addNewAttendance(startTime, endTime, params["userID_" + key].to_i)
						if wkattendance.id.present?
							sucessMsg = l(:notice_successful_update)
						else
            	err_msg += wkattendance.errors.full_messages.join(", ")
            end
					end
				rescue
					err_msg += wkattendance.errors.full_messages.join('\n')
				end
			end
		end
		render :plain => err_msg
	end

	def updateClockInOutEntry(id, startTime, endTime)
		wkattendance =  WkAttendance.find(id.to_i)
		if startTime != wkattendance.start_time && isChecked('att_save_geo_location')
			wkattendance.s_latitude = params[:latitude]
			wkattendance.s_longitude = params[:longitude]
		end
		if endTime.present? && isChecked('att_save_geo_location')
			wkattendance.e_latitude = params[:latitude]
			wkattendance.e_longitude = params[:longitude]
		end
		wkattendance.start_time =  startTime
		wkattendance.end_time = endTime
		wkattendance.hours = computeWorkedHours(wkattendance.start_time, wkattendance.end_time, true) if wkattendance.end_time.present?
		wkattendance.save()
		wkattendance
	end

	def get_clock_hours
		entries = findLastAttnEntry(true).first
		showClock = isChecked("wktime_enable_clock_in_out") && isChecked("wktime_enable_attendance_module")
		clock = {total_hours: 0, showClock: showClock, geoLocation: isChecked('att_save_geo_location')}
		totalHour = totalhours * 3600
		if entries.present?
			remaininghr = computeWorkedHours(entries.start_time, Time.now.localtime, false)
			clock['start_time'] = entries.start_time ? entries.start_time : nil
			clock['end_time'] = entries.end_time ? entries.end_time : nil
			clock['total_hours'] = !entries.end_time && (entries.start_time > 24.hour.ago) ?
				( !remaininghr.blank? ? remaininghr.round(0)+totalHour : totalHour) : totalHour
		end
		render json: clock
	end

	def leavesettings
		if request.post?
      setting = params[:settings] ? params[:settings].permit!.to_h : {}
			if setting.present?
				setting.each do |key, value|
					leaveSettings = WkSetting.where("name = ?", key ).first
					leaveSettings = WkSetting.new if leaveSettings.blank?
					leaveSettings.name = key
					leaveSettings.value = value
					leaveSettings.save()
				end
			else
				leaveSettings = WkSetting.where("name = 'leave_settings'").first
				leaveSettings.destroy if leaveSettings.present?
			end
			redirect_to controller: 'wkattendance', action: 'leavesettings', tab: 'leave'
			flash[:notice] = l(:notice_successful_update)
		end
		@leaveSettings = getLeaveSettings
	end
end
