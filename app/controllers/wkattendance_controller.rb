class WkattendanceController < ApplicationController	
unloadable 

include WktimeHelper
include WkattendanceHelper

before_filter :require_login
before_filter :check_perm_and_redirect, :only => [:edit, :update]

	def index
		sqlStr = ""
		if(Setting.plugin_redmine_wktime['wktime_leave'].blank?)
			sqlStr = " select u.id as user_id, -1 as issue_id from users u where u.type = 'User' "
		else
			listboxArr = Setting.plugin_redmine_wktime['wktime_leave'][0].split('|')
			issueId = listboxArr[0]
			sqlStr = getQueryStr + " where i.id in (#{issueId}) and u.type = 'User'"
		end
		if !isAccountUser
			sqlStr = sqlStr + " and u.id = #{User.current.id} " 
		end
		sqlStr = sqlStr + " order by u.firstname"
			
		findBySql(sqlStr)
	end
	
	def edit
		sqlStr = getQueryStr + " where i.id in (#{getLeaveIssueIds}) and u.type = 'User' and u.id = #{params[:user_id]}"
		@leave_details = WkUserLeave.find_by_sql(sqlStr)
		render :action => 'edit'
	end
	
	def update	
		errorMsg =nil
		wkuserleave = nil
		ids = params[:ids]
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
			wkuserleave.accrual_on = Date.civil(Date.today.year, Date.today.month, 1) -1
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
	
	def getLeaveIssueIds
		issueIds = ''
		if(Setting.plugin_redmine_wktime['wktime_leave'].blank?)
			issueIds = '-1'
		else
			Setting.plugin_redmine_wktime['wktime_leave'].each do |element|
				if issueIds!=''
					issueIds = issueIds +','
				end
			  listboxArr = element.split('|')
			  issueIds = issueIds + listboxArr[0]
			end
		end	
		issueIds
	end
	
	def getReportLeaveIssueIds
		issueIds = ''
		if(Setting.plugin_redmine_wktime['wktime_leave'].blank?)
			issueIds = '-1'
		else
			Setting.plugin_redmine_wktime['wktime_leave'].each_with_index do |element,index|
				if index < 3
					if issueIds!=''
						issueIds = issueIds +','
					end
				  listboxArr = element.split('|')
				  issueIds = issueIds + listboxArr[0]
				end
			end
		end	
		issueIds
	end
	
	def getQueryStr
		queryStr = ''
		queryStr = "select u.id as user_id, i.id as issue_id,w.balance, w.accrual, w.used, w.accrual_on, w.id from users u 
		cross join issues i left join (SELECT wl.* FROM wk_user_leaves wl inner join"
		queryStr = queryStr + " ( select max(accrual_on) as accrual_on, user_id, issue_id from wk_user_leaves 
			group by user_id, issue_id) t"
		queryStr = queryStr + " on wl.user_id = t.user_id and wl.issue_id = t.issue_id 
			and wl.accrual_on = t.accrual_on) w on w.user_id = u.id and w.issue_id = i.id"
		queryStr
	end
	
	def report
		retrieve_date_range
		if params[:report_type] == 'attendance_report'
			reportattn
		end
	end
	
	def reportattn
		dateStr = getConvertDateStr('start_time')
		sqlStr = ""
		if isAccountUser
			@userlist = User.where("type = ?", 'User').order('id')
			leave_data = WkUserLeave.where("issue_id in (#{getReportLeaveIssueIds}) and accrual_on between '#{@from}' and '#{@to}'")
			leave_entry = TimeEntry.where("issue_id in (#{getLeaveIssueIds}) and spent_on between '#{@from}' and '#{@to}'")
			sqlStr = "select user_id,#{dateStr} as spent_on,sum(hours) as hours from wk_attendances where start_time between '#{@from}' and '#{@to}' group by user_id,#{dateStr}"
		else
			@userlist = User.where("type = ? AND id = ?", 'User', User.current.id)
			leave_data = WkUserLeave.where("issue_id in (#{getReportLeaveIssueIds}) and accrual_on between '#{@from}' and '#{@to}' and user_id = #{User.current.id} " )
			leave_entry = TimeEntry.where("issue_id in (#{getLeaveIssueIds}) and spent_on between '#{@from}' and '#{@to}' and user_id = #{User.current.id} " )
			sqlStr = "select user_id,#{dateStr} as spent_on,sum(hours) as hours from wk_attendances where start_time between '#{@from}' and '#{@to}' and user_id = #{User.current.id} group by user_id,#{dateStr}"
		end
		daily_entries = WkAttendance.find_by_sql(sqlStr)
		@attendance_entries = Hash.new
		if !leave_data.blank?
			leave_data.each_with_index do |entry,index|
				@attendance_entries[entry.user_id.to_s + '_' + entry.issue_id.to_s + '_balance'] = entry.balance
				@attendance_entries[entry.user_id.to_s + '_' + entry.issue_id.to_s + '_used'] = entry.used
				@attendance_entries[entry.user_id.to_s + '_' + entry.issue_id.to_s + '_accrual'] = entry.accrual
			end
		end
		if !leave_entry.blank?
			 leave_entry.each_with_index do |entry,index|
				 @attendance_entries[entry.user_id.to_s + '_' + entry.spent_on.strftime("%d").to_i.to_s + '_leave'] = entry.issue_id
			end
		end
		if !daily_entries.blank?
			 daily_entries.each_with_index do |entry,index|
				 @attendance_entries[entry.user_id.to_s + '_' + entry.spent_on.strftime("%d").to_i.to_s  + '_hours'] = entry.hours
			end
		end
		render :action => 'reportattn'
	end
	
	# Retrieves the date range based on predefined ranges or specific from/to param dates
	  def retrieve_date_range
		@free_period = false
		@from, @to = nil, nil
		period_type = params[:period_type]
		period = params[:period]
		fromdate = params[:from]
		todate = params[:to]

		if (period_type == '1' || (period_type.nil? && !period.nil?)) 
		  case period.to_s
		  when 'current_month'
			@from = Date.civil(Date.today.year, Date.today.month, 1)
			@to = (@from >> 1) - 1
		  when 'last_month'
			@from = Date.civil(Date.today.year, Date.today.month, 1) << 1
			@to = (@from >> 1) - 1
		  end
		elsif period_type == '2' || (period_type.nil? && (!fromdate.nil? || !todate.nil?))
		  begin; @from = Date.civil((fromdate.to_s.to_date).year,(fromdate.to_s.to_date).month, 1) unless fromdate.blank?; rescue; end
		  begin;  @to = (@from >> 1) - 1 unless @from.blank?; rescue; end
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
		
		@from, @to = @to, @from if @from && @to && @from > @to

	  end
	
	def getIssuesByProject
		issue_by_project=""
		issueList=[]				
		issueList = getPrjIssues
		issueList.each do |issue|
			issue_by_project << issue.id.to_s() + ',' + issue.subject + "\n"
		end
		respond_to do |format|
			format.text  { render :text => issue_by_project }
		end
	end	
	
	def getPrjIssues
		issueList = []
		project_id = 0
		if !params[:project_id].blank?
			project_id = params[:project_id]
		end
		issueList = Issue.where(:project_id => project_id)
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
		return (ret || isAccountUser)
	end
	
	def getProjectByIssue
		project_id=""
		if !params[:issue_id].blank?
			issue_id = params[:issue_id]
			issues = Issue.where(:id => issue_id.to_i)
			project_id = issues[0].project_id
		end
		respond_to do |format|
			format.text  { render :text => project_id }
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
	
	def findBySql(query)
		result = WkUserLeave.find_by_sql("select count(*) as id from (" + query + ") as v2")
		@entry_count = result.blank? ? 0 : result[0].id
        setLimitAndOffset()		
		rangeStr = formPaginationCondition()
		
		@leave_entries = WkUserLeave.find_by_sql(query + rangeStr )
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
	
end
