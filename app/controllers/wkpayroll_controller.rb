class WkpayrollController < WkbaseController

before_filter :require_login

include WkpayrollHelper	
include WktimeHelper

	def index
        @payroll_entries = nil
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
		user_id = session[:wkpayroll][:user_id]
		group_id = session[:wkpayroll][:group_id]
		
		if user_id.blank?
		   ids = User.current.id
		elsif user_id.to_i != 0 && group_id.to_i == 0
		   ids = user_id.to_i
		elsif group_id.to_i != 0
		   ids =user_id.to_i == 0 ? (userIds.blank? ? 0 : userIds.join(',')) : user_id.to_i
		else
		   ids = userIds.join(',')
		end
		
		sqlQuery = " select vw.user_id as user_id, u.firstname as firstname,u.lastname as lastname," + 
		" vw.salary_date as salarydate, vw.allowance as allowance, vw.deduction as deduction," + 
		" vw.basic as basic, vw.currency as currency from (select v.user_id as user_id, v.salary_date as salary_date, max(v.currency) as currency," + 
		" sum(allowance) as allowance, sum(deduction) as deduction, sum(basic) as basic" +
        " from (select ws.user_id, ws.salary_date, max(ws.currency) as currency," +
		" SUM(CASE WHEN wsc.component_type = 'a' THEN ws.amount END) AS allowance," +
		" SUM(CASE WHEN wsc.component_type = 'd' THEN ws.amount END) AS deduction," +
		" SUM(CASE WHEN wsc.component_type = 'b' THEN ws.amount END) AS basic" +
		" from wk_salaries ws inner join wk_salary_components wsc on wsc.id = ws.salary_component_id" +
        " group by ws.user_id,wsc.component_type,ws.salary_date) v " +
		" group by v.user_id,v.salary_date) vw  inner join users u on u.id = vw.user_id" +
		" where vw.user_id in (#{ids}) "
		
		if !@from.blank? && !@to.blank?
			sqlQuery = sqlQuery + " and vw.salary_date between '#{@from}' and '#{@to}'"
		end
		
		sqlQuery = sqlQuery + " order by u.firstname,vw.salary_date desc"
        findBySql(sqlQuery)	
	end

	def edit
		userid = params[:user_id]
		salarydate = params[:salary_date]
		getSalaryDetail(userid,salarydate)
		render :action => 'edit'
	end
	
	def getSalaryDetail(userid,salarydate)
		sqlStr = getQueryStr + " where s.user_id = #{userid} and s.salary_date='#{salarydate}'"
		@wksalaryEntries = WkUserSalaryComponents.find_by_sql(sqlStr)
	end
	
	def getQueryStr
		queryStr = "select u.id as id, u.firstname as firstname, u.lastname as lastname, sc.name as component_name, sc.id as sc_component_id, cvj.value as joining_date, s.salary_date as salary_date,"+
		" s.amount as amount, s.currency as currency, sc.component_type as component_type from wk_salaries s "+ 
		" inner join wk_salary_components sc on s.salary_component_id=sc.id"+  
		" inner join users u on s.user_id=u.id left join custom_values cvj on (u.id = cvj.customized_id and cvj.custom_field_id = 0 ) "
	end

	def updateUserSalary
		userId = params[:user_id]
		salaryComponents = getSalaryComponentsArr
		errorMsg = nil
		salaryComponents.each do |entry| 
			componentId = entry[1]
			userSalarycomp = WkUserSalaryComponents.where("user_id = #{userId} and salary_component_id = #{componentId}")
			wkUserSalComp = userSalarycomp[0] 
			userSettingHash = getUserSettingHistoryHash(wkUserSalComp) unless wkUserSalComp.blank?
			if params['is_override' + componentId.to_s()].blank?
				unless wkUserSalComp.blank?
					saveUsrSalCompHistory(userSettingHash) 
					wkUserSalComp.destroy()
				end			
			else
				dependentId = params['dependent_id' + componentId.to_s()].to_i 
				factor = params['factor' + componentId.to_s()]
				if wkUserSalComp.blank?
					wkUserSalComp = WkUserSalaryComponents.new
					wkUserSalComp.user_id = userId
					wkUserSalComp.salary_component_id = componentId
					wkUserSalComp.dependent_id = dependentId if dependentId > 0
					wkUserSalComp.factor = factor 
				else
					wkUserSalComp.dependent_id = dependentId if dependentId > 0 
					wkUserSalComp.factor = factor 
				end
				if (wkUserSalComp.changed? && !wkUserSalComp.new_record?) || wkUserSalComp.destroyed?
					saveUsrSalCompHistory(userSettingHash) 
				end
				
				if !wkUserSalComp.save()
					errorMsg = wkuserleave.errors.full_messages.join('\n')
				end
			end
		end
		if errorMsg.nil?	
			redirect_to :action => 'index' , :tab => 'wkpayroll'
			flash[:notice] = l(:notice_successful_update)
		else
			flash[:error] = errorMsg
			redirect_to :action => 'edit'
		end	
	end
	
	def gensalary
	end
	
	def generatePayroll
		salaryDate = params[:salarydate].to_date
		errorMsg = generateSalaries(salaryDate)
		if errorMsg.nil?	
			redirect_to :action => 'index' , :tab => 'wkpayroll'
			flash[:notice] = l(:notice_successful_update)
		else
			flash[:error] = errorMsg
			redirect_to :action => 'index'
		end	
	end

	def user_salary_settings
		userId = params[:user_id]
		sqlStr = getUserSalaryQueryStr
		sqlStr = sqlStr + "Where u.id = #{userId} and u.type = 'User'" +
		"order by u.id, sc.id"
		@userSalaryEntries = WkUserSalaryComponents.find_by_sql(sqlStr)
	end

	def saveUsrSalCompHistory(userSalCompHash)
		wkHUserSalComp = WkHUserSalaryComponents.new
		userSalCompHash.each do |key, value|
			wkHUserSalComp[key] = value
		end
		wkHUserSalComp.save()
	end

	def getUserSettingHistoryHash(userSettingObj)
		hUserSettingHash = Hash.new
		hUserSettingHash['user_id'] = userSettingObj.user_id
		hUserSettingHash['user_salary_component_id'] = userSettingObj.id
		hUserSettingHash['salary_component_id'] = userSettingObj.salary_component_id
		hUserSettingHash['dependent_id'] = userSettingObj.dependent_id
		hUserSettingHash['factor'] = userSettingObj.factor
		hUserSettingHash['created_at'] = userSettingObj.created_at
		hUserSettingHash['updated_at'] = userSettingObj.updated_at 
		hUserSettingHash
	end
	
    def findBySql(query)
		result = WkSalary.find_by_sql("select count(*) as id from (" + query + ") as v2")
	    @entry_count = result.blank? ? 0 : result[0].id
	    setLimitAndOffset()		
	    rangeStr = formPaginationCondition()	
	    @payroll_entries = WkSalary.find_by_sql(query + rangeStr)
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
	
	def formPaginationCondition
		rangeStr = ""
		if ActiveRecord::Base.connection.adapter_name == 'SQLServer'				
			rangeStr = " OFFSET " + @offset.to_s + " ROWS FETCH NEXT " + @limit.to_s + " ROWS ONLY "
		else		
			rangeStr = " LIMIT " + @limit.to_s +	" OFFSET " + @offset.to_s
		end
		rangeStr
	end

	def set_filter_session
        if params[:searchlist].blank? && session[:wkpayroll].nil?
			session[:wkpayroll] = {:period_type => params[:period_type],:period => params[:period],
			                       :group_id => params[:group_id], :user_id => params[:user_id], 
								   :from => @from, :to => @to}
		elsif params[:searchlist] =='wkpayroll'
			session[:wkpayroll][:period_type] = params[:period_type]
			session[:wkpayroll][:period] = params[:period]
			session[:wkpayroll][:group_id] = params[:group_id]
			session[:wkpayroll][:user_id] = params[:user_id]
			session[:wkpayroll][:from] = params[:from]
			session[:wkpayroll][:to] = params[:to]
		end
		
   end
   
   def getMembersbyGroup
		group_by_users=""
		userList=[]
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
			group_id = session[:wkpayroll][:group_id]
		end
		
		if !group_id.blank? && group_id.to_i > 0
			userList = User.in_group(group_id) 
		else
			userList = User.order("#{User.table_name}.firstname ASC,#{User.table_name}.lastname ASC")
		end
		userList
	end
	
   # Retrieves the date range based on predefined ranges or specific from/to param dates
	def retrieve_date_range
		@free_period = false
		@from, @to = nil, nil
		period_type = session[:wkpayroll][:period_type]
		period = session[:wkpayroll][:period]
		fromdate = session[:wkpayroll][:from]
		todate = session[:wkpayroll][:to]
		
		if (period_type == '1' || (period_type.nil? && !period.nil?)) 
		    case period.to_s
			  when 'today'
				@from = @to = Date.today
			  when 'yesterday'
				@from = @to = Date.today - 1
			  when 'current_week'
				@from = getStartDay(Date.today - (Date.today.cwday - 1)%7)
				@to = @from + 6
			  when 'last_week'
				@from =getStartDay(Date.today - 7 - (Date.today.cwday - 1)%7)
				@to = @from + 6
			  when '7_days'
				@from = Date.today - 7
				@to = Date.today
			  when 'current_month'
				@from = Date.civil(Date.today.year, Date.today.month, 1)
				@to = (@from >> 1) - 1
			  when 'last_month'
				@from = Date.civil(Date.today.year, Date.today.month, 1) << 1
				@to = (@from >> 1) - 1
			  when '30_days'
				@from = Date.today - 30
				@to = Date.today
			  when 'current_year'
				@from = Date.civil(Date.today.year, 1, 1)
				@to = Date.civil(Date.today.year, 12, 31)
	        end
		elsif period_type == '2' || (period_type.nil? && (!fromdate.nil? || !todate.nil?))
		    begin; @from = fromdate.to_s.to_date unless fromdate.blank?; rescue; end
		    begin; @to = todate.to_s.to_date unless todate.blank?; rescue; end
		    @free_period = true
		else
		  # default
		  # 'current_month'		
			@from = Date.civil(Date.today.year, Date.today.month, 1)
			@to = (@from >> 1) - 1
	    end    
		
		@from, @to = @to, @from if @from && @to && @from > @to

	end
	
	def payslip_rpt
		userId = (session[:wkreport][:user_id].blank? || (session[:wkreport][:user_id]).to_i < 1) ? User.current.id : session[:wkreport][:user_id]
		from = session[:wkreport][:from]
		to = session[:wkreport][:to]
		minSalaryDate = WkSalary.where("salary_date between '#{from}' and '#{to}'").minimum(:salary_date)
		if minSalaryDate.blank?
			@wksalaryEntries = nil
		else
			getSalaryDetail(userId,minSalaryDate.to_date)
			@userYTDAmountHash = getYTDDetail(userId,minSalaryDate.to_date)
		end
		render :action => 'payslip_rpt', :layout => false
	end	
	
	def getYTDDetail(userId,salaryDate)
		financialPeriod = getFinancialPeriod(salaryDate-1)
		ytdDetails = WkSalary.select("sum(amount) as amount, user_id, salary_component_id").where("user_id = #{userId} and salary_date between '#{financialPeriod[0]}' and '#{salaryDate}'").group("user_id, salary_component_id")
		ytdAmountHash = Hash.new()
		ytdDetails.each do |entry|
			ytdAmountHash[entry.salary_component_id] = entry.amount
		end
		ytdAmountHash
	end
end