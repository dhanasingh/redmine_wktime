class WkattendanceController < ApplicationController	
unloadable  

include WktimeHelper
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
			
		@leave_entries = WkUserLeave.find_by_sql(sqlStr)
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
			wkuserleave.accrual_on = Date.today
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
end
