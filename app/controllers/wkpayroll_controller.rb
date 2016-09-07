class WkpayrollController < WkbaseController

before_filter :require_login
include WkpayrollHelper	

	def index
	end

	def edit
		#getUserSalaryHash
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

	def user_salary_settings
		userId = params[:user_id]
		sqlStr = getUserSalaryQueryStr
		sqlStr = sqlStr + "Where u.id = #{userId} " +
		"order by u.id, sc.id"
		@userSalaryEntries = WkUserSalaryComponents.find_by_sql(sqlStr)
	end
	
	def getUserSalaryQueryStr
		sqlStr = "SELECT sc.id as sc_id, sc.name as sc_name, sc.frequency as sc_frequency, " + 
		"sc.start_date as sc_start_date, sc.dependent_id as sc_dependent_id, " + 
		"sc.factor as sc_factor, sc.salary_type as sc_salary_type, " + 
		"usc.factor as usc_factor, usc.dependent_id as usc_dependent_id, " + 
		"usc.salary_component_id as salary_component_id, usc.id as user_salary_component_id, " + 
		"u.id as user_id, u.firstname as firstname, u.lastname as lastname, "+ 
		"case when usc.id is null then sc.dependent_id else usc.dependent_id end as dependent_id, " + 
		"case when usc.id is null then sc.factor else usc.factor end as factor FROM users u " + 
		"left join wk_salary_components sc on (1 = 1) " + 
		"left join wk_user_salary_components usc on (sc.id = usc.salary_component_id and  usc.user_id = u.id) " 
		sqlStr
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
	
	def getUserSalaryHash
		@userSalaryHash = Hash.new()
		queryStr = getUserSalaryQueryStr + " order by u.id, sc.id" 
		userSalaries = WkUserSalaryComponents.find_by_sql(queryStr)
		salaryComponents = getSalaryComponentsArr
		@userSalEntryHash = Hash[userSalaries.map { |cf| [cf.sc_id.to_s + '_' + cf.user_id.to_s, cf] }]
		
		userSalaries.each do |entry|
			if @userSalaryHash[entry.user_id].blank?
				salDetailHash = Hash.new()
				if entry.dependent_id.blank?
					salDetailHash[entry.sc_id] = entry.factor
				else
					salDetailHash[entry.sc_id] = computeFactor(entry.user_id,entry.dependent_id,entry.factor)
				end
				@userSalaryHash[entry.user_id] = salDetailHash
			else
				if entry.dependent_id.blank?
					@userSalaryHash[entry.user_id][entry.sc_id] = entry.factor
				else
					@userSalaryHash[entry.user_id][entry.sc_id] = computeFactor(entry.user_id,entry.dependent_id,entry.factor)
				end
			end
		end
	end
	
	def computeFactor(userId, dependentId, factor)
		salEntry = @userSalEntryHash[dependentId.to_s + '_' + userId.to_s]
		factor = factor*(salEntry.factor.blank? ? 0 : salEntry.factor)
		if !salEntry.dependent_id.blank?
			factor = computeFactor(userId, salEntry.dependent_id, factor)
		end
		amount = factor
		factor
	end

end