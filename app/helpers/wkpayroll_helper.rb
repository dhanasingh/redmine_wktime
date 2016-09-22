module WkpayrollHelper
	include WktimeHelper
	include WkattendanceHelper
	require 'date'
	def getSalaryComponentsArr
		salaryComponents = Array.new
		allComponents = WkSalaryComponents.all #find_by_sql("SELECT id, name from wk_salary_components")
		salaryComponents << [ "", '-1' ] if allComponents.count > 1
		unless allComponents.blank?
			allComponents.each do |i|		
				salaryComponents << [ i.name , i.id ] 
			end
		end
		salaryComponents
	end
	
	def getFinancialPeriod(salaryDate)
		financialMonthStr = Setting.plugin_redmine_wktime['wktime_financial_year_start']
		if financialMonthStr.blank? || financialMonthStr.to_i == 0
			financialMonthStr = '4'
		end
		if salaryDate.month > financialMonthStr.to_i
			financialStart = Date.civil(salaryDate.year, financialMonthStr.to_i, 1)
			financialEnd = Date.civil(salaryDate.year+1, financialMonthStr.to_i, 1)
		else
			financialStart = Date.civil(salaryDate.year-1, financialMonthStr.to_i, 1)
			financialEnd = Date.civil(salaryDate.year, financialMonthStr.to_i, 1)
		end
		financialPeriod = [financialStart,financialEnd-1]
		financialPeriod
	end
	
	def generateSalaries(salaryDate)
		userSalaryHash = getUserSalaryHash(salaryDate)
		payperiod = Setting.plugin_redmine_wktime['wktime_pay_period']
		currency = Setting.plugin_redmine_wktime['wktime_payroll_currency']
		errorMsg = nil
		deleteWkSalaries(nil,salaryDate)
		userSalaryHash.each do |userId, salary|
			salary.each do |componentId, amount|
				userSalary = WkSalary.new
				userSalary.user_id = userId
				userSalary.currency = currency
				userSalary.amount = amount.round
				userSalary.salary_component_id = componentId
				userSalary.salary_date = salaryDate
				if !userSalary.save()
					errorMsg = wkuserleave.errors.full_messages.join('\n')
				end
			end
		end
		errorMsg
	end
	
	def getUserSalaryHash(salaryDate)
		userSalaryHash = Hash.new()
		payPeriod = getPayPeriod(salaryDate)
		queryStr = getUserSalaryQueryStr + " Where u.type = 'User' and (cvt.value is null or #{getConvertDateStr('cvt.value')} >= '#{payPeriod[0]}')" + " order by u.id, sc.salary_type" 
		userSalaries = WkUserSalaryComponents.find_by_sql(queryStr)
		salaryComponents = getSalaryComponentsArr
		@userSalEntryHash = Hash[userSalaries.map { |cf| [cf.sc_id.to_s + '_' + cf.user_id.to_s, cf] }]
		lastUserId = -1
		multiplier = 1.0
		
		userSalaries.each do |entry|
			isAddSalComp = isAddCompToSal(entry,payPeriod)
			if isAddSalComp
				if lastUserId != entry.user_id
					if entry.sc_salary_type == 'h'
						multiplier = getWorkedHours(entry.user_id, payPeriod[0], payPeriod[1])
						lastUserId = entry.user_id
					else
						multiplier = 1.0
						terminationDate = nil
						if !entry.termination_date.blank? && entry.termination_date.to_date.between?(payPeriod[0],payPeriod[1])
							terminationDate = entry.termination_date.to_date
						end
						multiplier = computeProrate(payPeriod,terminationDate,entry.user_id)
						lastUserId = entry.user_id
					end
				end
				if userSalaryHash[entry.user_id].blank?
					salDetailHash = Hash.new()
					if entry.dependent_id.blank?
						salDetailHash[entry.sc_id] = (entry.factor)*multiplier
					else
						salDetailHash[entry.sc_id] = computeFactor(entry.user_id,entry.dependent_id,entry.factor,multiplier)
					end
					userSalaryHash[entry.user_id] = salDetailHash
				else
					if entry.dependent_id.blank?
						userSalaryHash[entry.user_id][entry.sc_id] = entry.factor*multiplier
					else
						userSalaryHash[entry.user_id][entry.sc_id] = computeFactor(entry.user_id,entry.dependent_id,entry.factor,multiplier)
					end
				end
			else
				if userSalaryHash[entry.user_id].blank? 
					userSalaryHash[entry.user_id] = { entry.sc_id => 0 }
				else
					userSalaryHash[entry.user_id][entry.sc_id] = 0
				end
			end
		end
		userSalaryHash
	end
	
	def getUserSalaryQueryStr
		sqlStr = "SELECT sc.id as sc_id, sc.name as sc_name, sc.frequency as sc_frequency, " + 
		"sc.start_date as sc_start_date, sc.dependent_id as sc_dependent_id, " + 
		"sc.factor as sc_factor, sc.salary_type as sc_salary_type, cvt.value as termination_date, " + 
		"usc.factor as usc_factor, usc.dependent_id as usc_dependent_id, " + 
		"usc.salary_component_id as salary_component_id, usc.id as user_salary_component_id, " + 
		"u.id as user_id, u.firstname as firstname, u.lastname as lastname, "+ 
		"case when usc.id is null then sc.dependent_id else usc.dependent_id end as dependent_id, " + 
		"case when usc.id is null then sc.factor else usc.factor end as factor FROM users u " + 
		"left join wk_salary_components sc on (1 = 1) " + 
		"left join wk_user_salary_components usc on (sc.id = usc.salary_component_id and  usc.user_id = u.id) " +
		"left join custom_values cvt on (u.id = cvt.customized_id and cvt.value != '' and cvt.custom_field_id = #{getSettingCfId('wktime_attn_terminate_date_cf')} ) "
		sqlStr
	end
	
	def isAddCompToSal(entryObj, payPeriod)
		isAddComp = true
		unless entryObj.sc_start_date.blank?
			isAddComp = false
			frequencyHash = getFrequencyHash()
			frequencyInMonths = frequencyHash[entryObj.sc_frequency]
			startDate = entryObj.sc_start_date.to_date
			for i in 0..1
				if ((payPeriod[i].month - startDate.month).abs) % frequencyInMonths < 1
					isAddComp = startDate.change(month: payPeriod[i].month, year: payPeriod[i].year).between?(payPeriod[0],payPeriod[1])
				end
			end
		end
		isAddComp
	end
	
	def getFrequencyHash
		frequency = { "m" => 1, "q" => 3, "sa" => 6, "a" =>12 }
	end
	
	def getPayPeriod(salaryDate)
		payPeriod = Setting.plugin_redmine_wktime['wktime_pay_period']
		payDay = Setting.plugin_redmine_wktime['wktime_pay_day']
		payPeriodArr = nil
		case payPeriod
			when 'bw' then payPeriodArr = [salaryDate-14,salaryDate-1]
			when 'w' then payPeriodArr = [salaryDate-7,salaryDate-1 ]
			else payPeriodArr = [salaryDate<<1,salaryDate-1]
		end
		payPeriodArr
	end
	
	#calculate Prorate multiplier for an user for the particular payPeriod
	def computeProrate(payPeriod, terminationDate,userId)
		# Last worked day by the user on the particular payPeriod
		lastWorkDateByUser = terminationDate.blank? ? payPeriod[1] : terminationDate
		multiplier = ((lastWorkDateByUser - payPeriod[0] + 1) - getLossOfPayDays(payPeriod,userId)) / (payPeriod[1] - payPeriod[0] + 1)
		multiplier
	end
	
	def getLossOfPayDays(payPeriod, userId)
		lossOfPayId = 0
		unless Setting.plugin_redmine_wktime['wktime_loss_of_pay'].blank?
			lossOfPayId  = Setting.plugin_redmine_wktime['wktime_loss_of_pay'].to_i
		end		
		lossOfPayHours = TimeEntry.where("user_id = #{userId} and spent_on between '#{payPeriod[0]}' and '#{payPeriod[1]}' and issue_id = #{lossOfPayId}").sum(:hours)
		defaultWorkTime = !Setting.plugin_redmine_wktime['wktime_default_work_time'].blank? ? Setting.plugin_redmine_wktime['wktime_default_work_time'].to_i : 8
		lossOfPayDays = (lossOfPayHours.to_f/defaultWorkTime.to_f)
		lossOfPayDays
	end
	
	def computeFactor(userId, dependentId, factor,multiplier)
		salEntry = @userSalEntryHash[dependentId.to_s + '_' + userId.to_s]
		factor = factor*(salEntry.factor.blank? ? 0 : salEntry.factor)*multiplier
		if !salEntry.dependent_id.blank?
			factor = computeFactor(userId, salEntry.dependent_id, factor,multiplier)
		end
		amount = factor
		factor
	end
	
	def deleteWkSalaries(userId, salaryDate)
		if !(userId.blank? || salaryDate.blank?)
			WkSalary.where(user_id: userId).where(salary_date: salaryDate).delete_all
		elsif !salaryDate.blank?
			WkSalary.where(salary_date: salaryDate).delete_all
		elsif !userId.blank?
			WkSalary.where(user_id: userId).delete_all
		else
			WkSalary.delete_all
		end
	end
	
	def savePayrollSettings(settingsValue)
		sval = Array.new
		dval = 	Array.new	
		settingsValue.select {|key,value| 
			if !value.blank?  
				if key.to_s == 'payroll_deleted_ids'
					dval = value.split('|')
					WkSalaryComponents.delete_all(:id => dval.map(&:to_i))
				else
					for i in 0..value.length-1			
						sval = value[i].split('|')		
						if !sval[0].blank?
							wksalaryComponents =  WkSalaryComponents.find(sval[0])
						else
							wksalaryComponents = WkSalaryComponents.new
						end
						if key.to_s == 'basic'				
							wksalaryComponents.name = sval[1]
							wksalaryComponents.component_type = 'b'
							wksalaryComponents.salary_type = sval[2]
							wksalaryComponents.factor = sval[3]				
						else
							wksalaryComponents.name = sval[1]
							wksalaryComponents.frequency = sval[2]
							wksalaryComponents.start_date = sval[3]
							wksalaryComponents.component_type = key.to_s == 'allowances' ? 'a' : 'd'
							wksalaryComponents.dependent_id = sval[4]
							wksalaryComponents.factor = sval[5]
						end
							wksalaryComponents.save()
					end
				end
			end		
		}
    end
end
