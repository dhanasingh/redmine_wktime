class WkreportController < ApplicationController	
unloadable 

include WktimeHelper
include WkreportHelper
include WkattendanceHelper

before_filter :require_login
before_filter :check_perm_and_redirect, :only => [:edit, :update]
	
	def index
		@groups = Group.sorted.all
		if params[:searchlist].blank? && session[:wkreport].nil?
			session[:wkreport] = {:group_id => params[:group_id]}
		elsif params[:searchlist] =='wkreport'
			session[:wkreport][:group_id] = params[:group_id]
		end
		retrieve_date_range
		if params[:report_type] == 'attendance_report'
			reportattn
		elsif params[:report_type] == 'time_report'
			time_rpt
			#redirect_to :action => 'time_rpt', :controller => 'wktime'
		end
	end
	
	def time_rpt
		#@user = User.current
		#@startday = getStartDay(Date.today)
		#@entries = findEntries()
		
		#render :action => 'time_rpt', :controller => 'wktime', :layout => false
		redirect_to :action => 'time_rpt', :controller => 'wktime'
	end
	
	def reportattn
		if !params[:group_id].blank?
			group_id = params[:group_id]
		else
			group_id = session[:wkreport][:group_id]
		end
		if group_id.blank?
			group_id = 0
		end	
		dateStr = getConvertDateStr('start_time')
		sqlStr = ""
		userSqlStr = getUserQueryStr(group_id)
		leaveSql = "select u.id as user_id, gu.group_id, i.id as issue_id, l.balance, l.accrual, l.used, l.accrual_on," + 
		" lm.balance + lm.accrual - lm.used as open_bal from users u" + 
		" left join groups_users gu on (gu.user_id = u.id and gu.group_id = #{group_id})" + 
		" cross join (select id from issues where id in (#{getReportLeaveIssueIds})) i" + 
		" left join (#{getLeaveQueryStr(@from,@to)}) l on l.user_id = u.id and l.issue_id = i.id" + 
		" left join (#{getLeaveQueryStr(@from << 1,@from - 1)}) lm on lm.user_id = u.id and i.id = lm.issue_id"
		if group_id.to_i > 0
			leaveSql = leaveSql + " Where gu.group_id is not null"
		end
		if isAccountUser
			leave_entry = TimeEntry.where("issue_id in (#{getLeaveIssueIds}) and spent_on between '#{@from}' and '#{@to}'")
			sqlStr = "select user_id,#{dateStr} as spent_on,sum(hours) as hours from wk_attendances where #{dateStr} between '#{@from}' and '#{@to}' group by user_id,#{dateStr}"
		else
			leave_entry = TimeEntry.where("issue_id in (#{getLeaveIssueIds}) and spent_on between '#{@from}' and '#{@to}' and user_id = #{User.current.id} " )
			sqlStr = "select user_id,#{dateStr} as spent_on,sum(hours) as hours from wk_attendances where #{dateStr} between '#{@from}' and '#{@to}' and user_id = #{User.current.id} group by user_id,#{dateStr}"
		end
		findBySql(userSqlStr)
		#@userlist = User.find_by_sql(userSqlStr)
		leave_data = WkUserLeave.find_by_sql(leaveSql)
		daily_entries = WkAttendance.find_by_sql(sqlStr)
		@attendance_entries = Hash.new
		if !leave_data.blank?
			leave_data.each_with_index do |entry,index|
				@attendance_entries[entry.user_id.to_s + '_' + entry.issue_id.to_s + '_balance'] = entry.open_bal
				@attendance_entries[entry.user_id.to_s + '_' + entry.issue_id.to_s + '_used'] = entry.used
				@attendance_entries[entry.user_id.to_s + '_' + entry.issue_id.to_s + '_accrual'] = entry.accrual
			end
		end
		if !leave_entry.blank?
			 leave_entry.each_with_index do |entry,index|
				 @attendance_entries[entry.user_id.to_s + '_' + entry.spent_on.to_date.strftime("%d").to_i.to_s + '_leave'] = entry.issue_id
			end
		end
		if !daily_entries.blank?
			 daily_entries.each_with_index do |entry,index|
				 @attendance_entries[entry.user_id.to_s + '_' + entry.spent_on.to_date.strftime("%d").to_i.to_s  + '_hours'] = entry.hours.is_a?(Float) ? entry.hours.round(2) : entry.hours
			end
		end
		render :action => 'reportattn', :layout => false
	end
	
	def getUserQueryStr(group_id)
		queryStr = "select u.id , gu.group_id, u.firstname, u.lastname,cvt.value as termination_date, cvj.value as joining_date, " +
			"cvdob.value as date_of_birth, cveid.value as employee_id, cvdesg.value as designation from users u " +
			"left join groups_users gu on (gu.user_id = u.id and gu.group_id = #{group_id}) " +
			"left join custom_values cvt on (u.id = cvt.customized_id and cvt.value != '' and cvt.custom_field_id = #{getSettingCfId('wktime_attn_terminate_date_cf')} ) " +
			"left join custom_values cvj on (u.id = cvj.customized_id and cvj.custom_field_id = #{getSettingCfId('wktime_attn_join_date_cf')} ) " +
			"left join custom_values cvdob on (u.id = cvdob.customized_id and cvdob.custom_field_id = #{getSettingCfId('wktime_attn_user_dob_cf')} ) " +
			"left join custom_values cveid on (u.id = cveid.customized_id and cveid.custom_field_id = #{getSettingCfId('wktime_attn_employee_id_cf')} ) " +
			"left join custom_values cvdesg on (u.id = cvdesg.customized_id and cvdesg.custom_field_id = #{getSettingCfId('wktime_attn_designation_cf')} ) " +
			"where u.type = 'User' and (#{getConvertDateStr('cvt.value')} >= '#{@from}' or (u.status = #{User::STATUS_ACTIVE} and cvt.value is null))"
		if group_id.to_i > 0
			queryStr = queryStr + " and gu.group_id is not null"
		end
		if !isAccountUser
			queryStr = queryStr + " and u.id = #{User.current.id} "
		end
		#queryStr = queryStr + " order by u.created_on"
		queryStr
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
	
	def getLeaveQueryStr(from,to)
		queryStr = "select * from wk_user_leaves WHERE issue_id in (#{getLeaveIssueIds}) and accrual_on between '#{from}' and '#{to}'"
		if !isAccountUser
			queryStr = queryStr + " and user_id = #{User.current.id} "
		end
		queryStr
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
	
	def findBySql(query)
		result = WkUserLeave.find_by_sql("select count(*) as id from (" + query + ") as v2")
		@entry_count = result.blank? ? 0 : result[0].id
        setLimitAndOffset()		
		rangeStr = formPaginationCondition()		
		@userlist = WkUserLeave.find_by_sql(query + " order by u.created_on " + rangeStr )
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
	
end
