class WkattendanceController < ApplicationController	
unloadable 

include WktimeHelper
include WkattendanceHelper

before_filter :require_login
before_filter :check_perm_and_redirect, :only => [:edit, :update]

	def index
		@status = params[:status] || 1
		@groups = Group.all.sort
		sqlStr = ""
		lastMonthStartDt = Date.civil(Date.today.year, Date.today.month, 1) << 1
		if(Setting.plugin_redmine_wktime['wktime_leave'].blank?)
			sqlStr = " select u.id as user_id, u.firstname, u.lastname, -1 as issue_id from users u where u.type = 'User' "
		else
			listboxArr = Setting.plugin_redmine_wktime['wktime_leave'][0].split('|')
			issueId = listboxArr[0]
			sqlStr = getListQueryStr + " where u.type = 'User' and (cvt.value is null or #{getConvertDateStr('cvt.value')} >= '#{lastMonthStartDt}')"
		end
		if !isAccountUser
			sqlStr = sqlStr + " and u.id = #{User.current.id} " 
		end
		if !@status.blank?
			sqlStr = sqlStr + " and u.status = #{@status}"
		end
		if !params[:group_id].blank?
			sqlStr = sqlStr + " and gu.group_id = #{params[:group_id]}"
		end
		if !params[:name].blank?
			sqlStr = sqlStr + " and (u.firstname like '%#{params[:name]}%' or u.lastname like '%#{params[:name]}%')"
		end
		findBySql(sqlStr)
	end
	
	def edit
		sqlStr = getQueryStr + " where i.id in (#{getLeaveIssueIds}) and u.type = 'User' and u.id = #{params[:user_id]} order by i.subject"
		@leave_details = WkUserLeave.find_by_sql(sqlStr)
		render :action => 'edit'
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
			"left join custom_values cvt on (u.id = cvt.customized_id and cvt.value != '' and cvt.custom_field_id = #{getSettingCfId('wktime_attn_terminate_date_cf')} ) " +
			"cross join issues i left join wk_user_leaves w on w.user_id = u.id and w.issue_id = i.id
			and w.accrual_on = '#{accrualOn}' " +
			" left join groups_users gu on u.id = gu.user_id"
		queryStr
	end
	
	def getListQueryStr
		accrualOn = params[:accrual_on].blank? ? Date.civil(Date.today.year, Date.today.month, 1) -1 : params[:accrual_on].to_s.to_date
		selectColStr = "select u.id as user_id, u.firstname, u.lastname"
		joinTableStr = ""
		Setting.plugin_redmine_wktime['wktime_leave'].each_with_index do |element,index|
			if index < 5
				tAlias = "w#{index.to_s}"
				listboxArr = element.split('|')
				joinTableStr = joinTableStr + "left join wk_user_leaves #{tAlias} on #{tAlias}.user_id = u.id and #{tAlias}.issue_id =" + listboxArr[0] + " and #{tAlias}.accrual_on = '#{accrualOn}'"
				selectColStr = selectColStr + ", (#{tAlias}.balance + #{tAlias}.accrual - #{tAlias}.used) as total#{index.to_s}"
			end
		end
		queryStr = selectColStr + " from users u left join custom_values cvt on (u.id = cvt.customized_id and cvt.value != '' and cvt.custom_field_id = #{getSettingCfId('wktime_attn_terminate_date_cf')} ) " + joinTableStr + " left join groups_users gu on u.id = gu.user_id"
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
		@leave_entries = WkUserLeave.find_by_sql(query + " order by u.firstname " + rangeStr )
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
