class WkattendanceController < ApplicationController	
unloadable 

include WktimeHelper
include WkattendanceHelper
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
	
	def getAttnLeaveIssueIds
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
		sqlStr = "select u.id as user_id,concat(u.firstname,' ' ,u.lastname) as user_name,vw.accrual_on,vw.leave1,vw.leave2,vw.leave3,vw1.opening_leave1,vw1.opening_leave2,vw1.opening_leave3,vw2.closing_leave1,vw2.closing_leave2,vw2.closing_leave3,vw3.* from users u left join 
		(" + getLeaveBalanceQuery(@from, @to,'') + ") vw on vw.user_id=u.id full join 
		(" + getLeaveBalanceQuery(@from<< 1, @to<< 1,'opening_') + ") vw1 on u.id = vw1.user_id full join 
		(" + getLeaveBalanceQuery(@from, @to,'closing_') + ") vw2 on u.id = vw2.user_id inner join 
		(" + getUsrMonthlyAttnQuery + ") vw3 on vw3.user_id = u.id where u.type = 'User' order by u.id"
		@attendance_entries = WkUserLeave.find_by_sql(sqlStr)
		render :action => 'reportattn'
	end
	
	def getLeaveBalanceQuery(from, to, balanceType)
		queryStr = " SELECT * FROM crosstab ('SELECT user_id, accrual_on, issue_id,"
		if balanceType == ''
			queryStr = queryStr + "  used "
		else
			queryStr = queryStr + "  balance "
		end
		queryStr = queryStr + "FROM (select u.id as user_id, i.id as issue_id, i.subject as issue_name, w.balance, w.accrual, w.used, w.accrual_on, w.id from users u 
				cross join issues i left join (SELECT wl.* FROM wk_user_leaves wl inner join( select max(accrual_on) as accrual_on, user_id, issue_id from wk_user_leaves 
					group by user_id, issue_id,accrual_on) t on wl.user_id = t.user_id and wl.issue_id = t.issue_id 
					and wl.accrual_on = t.accrual_on) w on w.user_id = u.id and w.issue_id = i.id where i.id in (#{getAttnLeaveIssueIds}) and accrual_on between ''#{from}'' and ''#{to}'') as vw ORDER BY 1',
		  'SELECT id as issue_id FROM issues where id in(#{getAttnLeaveIssueIds}) ORDER BY 1'
		)
		AS
		(
			   user_id integer,
			   accrual_on date,
			   "+balanceType+"leave1 float,
			   "+balanceType+"leave2 float,
			   "+balanceType+"leave3 float
		)"
		queryStr
	end
	
	def getUsrMonthlyAttnQuery
		dateStr = getConvertDateStr('start_time')
		queryStr = "select u.id as user_id,w.* from users u 
				left join (select * from crosstab(
		  'select CASE when t.user_id is not null then t.user_id else vw.user_id end as user_id,
			CASE when t.spent_on is not null then extract(day from t.spent_on) else extract(day from vw.spent_on) end as spent_on,
			CASE when t.issue_id is null then vw.hours::text else concat(vw.hours::text,''|'',t.issue_id) end as hours
			 from (select user_id, issue_id, spent_on from time_entries 
			where issue_id in (#{getLeaveIssueIds}) and spent_on between ''#{@from}'' and ''#{@to}'') t full join
			(select user_id,#{dateStr} as spent_on,extract(day from date(start_time)),sum(hours) as hours from wk_attendances 
			where #{dateStr} between ''#{@from}'' and ''#{@to}'' group by user_id,#{dateStr}) vw on vw.user_id=t.user_id and vw.spent_on = t.spent_on order by 1',
		  'select m from generate_series(1,31) m'
		) as (
		  vuser_id int,  a1 varchar,  a2 varchar,  a3 varchar,  a4 varchar,  a5 varchar,  a6 varchar,  a7 varchar,  a8 varchar,
		  a9 varchar,  a10 varchar,  a11 varchar,  a12 varchar,  a13 varchar,  a14 varchar,  a15 varchar,  a16 varchar,
		  a17 varchar,  a18 varchar,  a19 varchar,  a20 varchar,  a21 varchar,  a22 varchar,  a23 varchar,  a24 varchar,
		  a25 varchar,  a26 varchar,  a27 varchar,  a28 varchar,  a29 varchar,  a30 varchar,  a31 varchar
		)) w on w.vuser_id = u.id order by u.id"
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
		  #begin; @to = todate.to_s.to_date unless todate.blank?; rescue; end
		  @free_period = true
		else
		  # default
		  # 'current_month'		
			@from = Date.civil(Date.today.year, Date.today.month, 1)
			@to = (@from >> 1) - 1
		end    
		
		@from, @to = @to, @from if @from && @to && @from > @to

	  end
	
	def reportPdf
		send_data(wktime_report_to_pdf(), :type => 'application/pdf', :filename => "attendance.pdf")
	end
	
	
end
