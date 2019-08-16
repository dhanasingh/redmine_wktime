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
	
	def getIntervals(startDate, endDate, periodType, periodStart, inclusiveOfStart, inclusiveOfEnd)
		intervals = Array.new
		unless periodType.blank?
			case periodType.upcase
			when 'H'
				intervals << [startDate, endDate]
			when 'D'
				intervals << [startDate, endDate]
			when 'W'
				intervals = getIntervalInWeeks(startDate, endDate, periodStart, inclusiveOfStart, inclusiveOfEnd)
			else
				intervals = getFinancialPeriodArray(startDate, endDate, periodType, periodStart)
			end
		end
		intervals
	end
	
	def getFinancialPeriodArray(startDate, endDate, periodType, monthStart)
		finPeriodArr = Array.new
		frequencyMonth = getFrequencyHash[periodType.downcase]
		startFinDate = nil
		endFinDate  = nil
		startDate = startDate - (monthStart-1).days
		endDate = endDate - (monthStart-1).days
		financialStartMonth = getFinancialStart.to_i
		startDateModVal = getDateModValue(startDate, financialStartMonth, frequencyMonth)
		endDateModVal = getDateModValue(endDate, financialStartMonth, frequencyMonth)
		subtractorStrat = startDateModVal != 0 ? frequencyMonth - startDateModVal : 0
		subtractorEnd = endDateModVal == 0 ? frequencyMonth : endDateModVal
		startFinDate = Date.civil(startDate.year, startDate.month, monthStart) - subtractorStrat.months
		endFinDate = (Date.civil(endDate.year, endDate.month, monthStart) + subtractorEnd.months) - 1.day
		lastDate = startFinDate
		until lastDate > endFinDate
			finPeriodArr << [lastDate, (lastDate + frequencyMonth.months) -1.days ]
			lastDate = lastDate + frequencyMonth.months
		end
		finPeriodArr
	end
	
	# Return the intervals of week as array
	# startDay the day of calendar week (0-6, Sunday is 0)	
	# inclusiveOfStart - if true then includes the startDate's week  
	# inclusiveOfEnd - if true then includes the endDate's week  
	def getIntervalInWeeks(startDate, endDate, startDay, inclusiveOfStart, inclusiveOfEnd)
		intervalArr = Array.new
		periodStart = getWeekStartDt(startDate, startDay)	
		periodEnd = getWeekStartDt(endDate, startDay) + 6.days
		startIntervalDate = periodStart
		unless periodStart + 6.days == periodEnd
			unless inclusiveOfStart || startDate == periodStart
				startIntervalDate = periodStart + 7.days
			end
			endIntervalDate = periodEnd
			unless inclusiveOfEnd || endDate == periodEnd
				endIntervalDate = periodEnd - 7.days
			end
			lastDate = startIntervalDate
			until lastDate > endIntervalDate
				intervalArr << [lastDate, lastDate + 6.days ]
				lastDate = lastDate + 7.days
			end
		else
			intervalArr << [periodStart, periodStart + 6.days ] if inclusiveOfStart || inclusiveOfEnd
		end
		intervalArr
	end
	
	def getDateModValue(dateVal, stratMonth, monthFreq)
		modVal = (stratMonth + 12 - dateVal.month)%monthFreq
		modVal
	end
	
	def getFinancialStart
		financialMonthStr = Setting.plugin_redmine_wktime['wktime_financial_year_start']
		if financialMonthStr.blank? || financialMonthStr.to_i == 0
			financialMonthStr = '4'
		end
		financialMonthStr
	end
	
	def generateSalaries(userIds, salaryDate, isGeneratePayroll)
		@payrollList = Array.new		
		userSalaryHash = getUserSalaryHash(userIds,salaryDate)
		payperiod = Setting.plugin_redmine_wktime['wktime_pay_period']
		currency = Setting.plugin_redmine_wktime['wktime_currency']
		errorMsg = nil
		unless userSalaryHash.blank?
			userSalaryHash.each do |userId, salary|
				salary.each do |componentId, amount|
					@payrollList << {:user_id => userId, :salary_component_id => componentId, :amount => amount.round, :currency => currency, :salary_date => salaryDate}
				end
		 	end
			 errorMsg = SavePayroll(@payrollList,userIds,salaryDate) if isGeneratePayroll == "true"
		else	
			errorMsg = l(:error_wktime_save_nothing)
		end		
		basicledger = WkSalaryComponents.where("component_type = 'b' and ledger_id is not null ").count
		if errorMsg.blank? && isChecked('salary_auto_post_gl') && !Setting.plugin_redmine_wktime['wktime_cr_ledger'].blank? && 	basicledger.to_i != 0	
			errorMsg = generateGlTransaction(salaryDate)
		else
			errorMsg = 1
		end
		errorMsg
	end
	
	def getDependentValue(dependent_id, type, user_id)

		dependent_value = ""
		@userSalaries.each do |cf|
			if cf.sc_id.to_i == dependent_id.to_i && type == "component_type" && user_id == cf.user_id
				dependent_value = cf.sc_component_type
			elsif cf.sc_id.to_i == dependent_id.to_i && type == "salary_type" && user_id == cf.user_id
				dependent_value = cf.sc_salary_type
			end
		end
		dependent_value
	end

	def getAllTotals(user_id)

		totals = Hash.new()
		basic_total = 0
		allowance_total = 0
		deduction_total = 0

		@userSalaries.each do |cf|
			basic_total = basic_total + cf.factor if cf.sc_component_type == 'b' && cf.user_id == user_id
		end

		@userSalaries.each do |cf|
			if cf.sc_component_type == 'a' && cf.user_id == user_id
				allowance_total = allowance_total + (cf.dependent_id.blank? ? cf.factor : (getDependentValue(cf.dependent_id,"component_type", cf.user_id)== 'b' ? basic_total * cf.factor : 0))
			end
		end

		basic_allowance_total = basic_total + allowance_total

		@userSalaries.each do |cf|
			if cf.sc_component_type == 'd' && cf.user_id == user_id
				if cf.dependent_id.blank?
					dependent_total = cf.factor
				else
					case getDependentValue(cf.dependent_id, "component_type", cf.user_id)
					when 'b'
						dependent_total = basic_total * cf.factor
					when 'a'
						dependent_total = allowance_total * cf.factor
					when 'c'
						salary_type = getDependentValue(cf.dependent_id, "salary_type", cf.user_id)
						if salary_type == 'BAT'
							dependent_total = basic_allowance_total * cf.factor
						elsif salary_type == 'BT'
							dependent_total = basic_total * cf.factor
						elsif salary_type == 'AT'
							dependent_total = allowance_total * cf.factor
						else
							dependent_total = 0
						end
					else
						dependent_total = 0
					end
				end
				deduction_total = deduction_total + dependent_total
			end
		end
		totals['BT'] = basic_total
		totals['AT'] = allowance_total
		totals['DT'] = deduction_total
		totals['BAT'] = basic_allowance_total
		totals
	end

	def getUserSalaryHash(userIds,salaryDate)
		userSalaryHash = Hash.new()
		payPeriod = getPayPeriod(salaryDate)
		queryStr = getUserSalaryQueryStr + " Where (wu.termination_date is null or wu.termination_date >= '#{payPeriod[0]}') and sc.id is not null " 
		unless userIds.blank?
			queryStr = queryStr + " and u.id in (#{userIds}) "
		else
			queryStr = queryStr + " and u.type = 'User'"
		end
		queryStr = queryStr  + " order by u.id, sc.salary_type"
		@userSalaries = WkUserSalaryComponents.find_by_sql(queryStr)

		@userSalEntryHash = Hash.new()
		@userSalaries.each do |cf|
			if cf.sc_component_type == "c"
				totals = getAllTotals(cf.user_id)
				cf.factor = totals[cf.sc_salary_type]
			end
			@userSalEntryHash[cf.sc_id.to_s + '_' + cf.user_id.to_s] = cf
		end
		
		lastUserId = -1
		multiplier = 1.0
		
		@userSalaries.each do |entry|
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
		sqlStr = "SELECT sc.id as sc_id, sc.name as sc_name, sc.component_type as sc_component_type, sc.frequency as sc_frequency, " + 
		"sc.start_date as sc_start_date, sc.dependent_id as sc_dependent_id, " + 
		"sc.factor as sc_factor, sc.salary_type as sc_salary_type, wu.termination_date, " + 
		"usc.factor as usc_factor, usc.dependent_id as usc_dependent_id, " + 
		"usc.salary_component_id as salary_component_id, usc.id as user_salary_component_id, " + 
		"u.id as user_id, u.firstname as firstname, u.lastname as lastname, "+ 
		"case when usc.id is null then sc.dependent_id else usc.dependent_id end as dependent_id, " + 
		"case when usc.id is null then sc.factor else usc.factor end as factor FROM users u " + 
		"left join wk_salary_components sc on (1 = 1) " + 
		"left join wk_user_salary_components usc on (sc.id = usc.salary_component_id and  usc.user_id = u.id) " +
		"left join wk_users wu on u.id = wu.user_id "
		sqlStr
	end
	
	def isAddCompToSal(entryObj, payPeriod)
		isAddComp = true
		unless entryObj.sc_start_date.blank?
			isAddComp = false
			frequencyHash = getFrequencyHash()
			frequencyInMonths = frequencyHash[entryObj.sc_frequency].blank? ? 1 : frequencyHash[entryObj.sc_frequency]
			startDate = entryObj.sc_start_date.to_date
			for i in 0..1
				if ((payPeriod[i].month - startDate.month).abs) % frequencyInMonths < 1
					isAddComp = true #startDate.change(month: payPeriod[i].month, year: payPeriod[i].year).between?(payPeriod[0],payPeriod[1])
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
		
		multiplier = (getWorkingDaysCount(payPeriod[0],lastWorkDateByUser) - getLossOfPayDays(payPeriod,userId)) / getWorkingDaysCount(payPeriod[0],payPeriod[1])
		multiplier
	end
	
	def getWorkingDaysCount(from,to)
		ndays = Setting.non_working_week_days
		totalDays = (to - from +1).to_i
		periodStartDay = from.wday
		nonWorkingDays = (totalDays/7).to_i*ndays.size
		remainingDays = (totalDays%7).to_i
		if remainingDays>0
			for i in 1 .. remainingDays
				dayVal = ((periodStartDay + i - 1)%7).to_i != 0 ? ((periodStartDay + i - 1)%7).to_s : "7"
				if ndays.include? dayVal
					nonWorkingDays = nonWorkingDays + 1
				end
			end
		end
		workingDays = totalDays - nonWorkingDays
		workingDays
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
			WkSalary.where("user_id in (#{userId}) ").where(salary_date: salaryDate).delete_all
		elsif !salaryDate.blank?
			WkSalary.where(salary_date: salaryDate).delete_all
		elsif !userId.blank?
			WkSalary.where("user_id in (#{userId}) ").delete_all
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
					WkSalaryComponents.where(:id => dval.map(&:to_i)).delete_all
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
							wksalaryComponents.ledger_id = sval[4]							
						elsif key.to_s != 'Calculated_Fields'
							wksalaryComponents.name = sval[1]
							wksalaryComponents.frequency = sval[2]
							wksalaryComponents.start_date = sval[3]
							wksalaryComponents.component_type = key.to_s == 'allowances' ? 'a' : 'd'
							wksalaryComponents.dependent_id = sval[4]
							wksalaryComponents.factor = sval[5]
							wksalaryComponents.ledger_id = sval[6]
						else
							wksalaryComponents.name = sval[1]
							wksalaryComponents.component_type = 'c'
							wksalaryComponents.salary_type = sval[2]
						end
							wksalaryComponents.save()
					end
				end
			end		
		}
    end
	
	def generateGlTransaction(salaryDate)
		errorMsg = nil
		totalDebit = 0
		totalCredit = 0
		salaries = WkSalary.includes(:salary_component).where("wk_salaries.salary_date = ?  and wk_salary_components.ledger_id is not null ", salaryDate).references(:salary_component).group("wk_salary_components.ledger_id").sum("wk_salaries.amount")
		
		allowanceAmt = WkSalary.includes(:salary_component).where("wk_salaries.salary_date = ? and wk_salary_components.component_type='a' and wk_salary_components.ledger_id is null ", salaryDate).references(:salary_component).sum("wk_salaries.amount")
		
		ledgerIds = WkSalaryComponents.pluck(:ledger_id, :component_type)
		ledgersIdHash = Hash[*ledgerIds.flatten]
		basicLedgerId = WkSalaryComponents.where("component_type = 'b' ").first.ledger_id 		
		salaries[basicLedgerId] = salaries[basicLedgerId].to_i + allowanceAmt.to_i
		crLedgerId = Setting.plugin_redmine_wktime['wktime_cr_ledger'].to_i
		transTypeArr = WkLedger.where(:id => crLedgerId).pluck(:id, :ledger_type)
		transTypeHash = Hash[*transTypeArr.flatten]
		
		glTransaction = WkGlTransaction.new
		glTransaction.trans_type = transTypeHash[Setting.plugin_redmine_wktime['wktime_cr_ledger'].to_i] == "BA" || transTypeHash[Setting.								plugin_redmine_wktime['wktime_cr_ledger'].to_i] == "CS" ? "P" : "J" 
		glTransaction.trans_date = salaryDate
		unless glTransaction.valid?
			errorMsg = glTransaction.errors.full_messages.join("<br>")
		else 
			glTransaction.save()
		end
		
		salaries.each{|key,value|
			wktxnDetail = WkGlTransactionDetail.new
			wktxnDetail.ledger_id = key.to_i
			wktxnDetail.gl_transaction_id = glTransaction.id
			wktxnDetail.detail_type = ledgersIdHash[key.to_i] == 'd' ? 'c' : 'd'
			wktxnDetail.amount = value
			wktxnDetail.currency = Setting.plugin_redmine_wktime['wktime_currency']
			totalDebit = totalDebit + value.to_i if ledgersIdHash[key.to_i] == 'b' || ledgersIdHash[key.to_i] == 'a'
			totalCredit = totalCredit + value.to_i if ledgersIdHash[key.to_i] == 'd'
			unless wktxnDetail.valid?
				errorMsg = wktxnDetail.errors.full_messages.join("<br>")
			else 
				wktxnDetail.save() if wktxnDetail.amount != 0
			end
		}
		wktxnDetail = WkGlTransactionDetail.new
		wktxnDetail.ledger_id = Setting.plugin_redmine_wktime['wktime_cr_ledger'].to_i
		wktxnDetail.gl_transaction_id = glTransaction.id
		wktxnDetail.detail_type = 'c'
		wktxnDetail.amount = totalDebit - totalCredit
		wktxnDetail.currency = Setting.plugin_redmine_wktime['wktime_currency']
		unless wktxnDetail.valid?
			errorMsg = wktxnDetail.errors.full_messages.join("<br>")
		else 
			wktxnDetail.save()
		end
		deleteGlSalary(salaryDate)
		glSalary = WkGlSalary.new
		glSalary.salary_date = salaryDate
		glSalary.gl_transaction_id = glTransaction.id
		unless glSalary.valid?
			errorMsg = glSalary.errors.full_messages.join("<br>")
		else 
			glSalary.save()
		end
		errorMsg
	end
	
	def deleteGlSalary(salaryDate)
		WkGlSalary.where(:salary_date =>salaryDate).destroy_all
	end
	
	def getSalaryDetail(userid,salarydate)
		sqlStr = getQueryStr + " where s.user_id = #{userid} and s.salary_date='#{salarydate}'"
		@wksalaryEntries = WkUserSalaryComponents.find_by_sql(sqlStr)
	end
	
	def getQueryStr
		#joinDateCFId = !Setting.plugin_redmine_wktime['wktime_attn_join_date_cf'].blank? ? Setting.plugin_redmine_wktime['wktime_attn_join_date_cf'].to_i : 0
		queryStr = "select u.id as user_id, u.firstname as firstname, u.lastname as lastname, sc.name as component_name, sc.id as sc_component_id, wu.join_date," + 
		" wu.id1, wu.gender,"+
		"  s.salary_date as salary_date, s.amount as amount, s.currency as currency," + 
		" sc.component_type as component_type from wk_salaries s "+ 
		" inner join wk_salary_components sc on s.salary_component_id=sc.id"+  
		" inner join users u on s.user_id=u.id" + 
		" left join wk_users wu on u.id = wu.user_id "
	end
	
	def getYTDDetail(userId,salaryDate)
		financialPeriodArr = getFinancialPeriodArray(salaryDate, salaryDate, 'a', 1)
		@financialPeriod = financialPeriodArr[0] 
		ytdDetails = WkSalary.select("sum(amount) as amount, user_id, salary_component_id").where("user_id = #{userId} and salary_date between '#{@financialPeriod[0]}' and '#{salaryDate}'").group("user_id, salary_component_id")
		ytdAmountHash = Hash.new()
		ytdDetails.each do |entry|
			ytdAmountHash[entry.salary_component_id] = entry.amount
		end
		ytdAmountHash
	end
	def get_calculated_field_types
		{
			l(:label_basic_allowance_total) => 'BAT',
			l(:label_allowance_total) => 'AT',
			l(:label_basic_total) => 'BT',
			l(:label_deduction) => "DT"
		}
	end

	def SavePayroll(payrollList,userIds,salaryDate)
		deleteWkSalaries(userIds, salaryDate)
		errorMsg = nil
		payrollList.each do |list|
			userSalary = WkSalary.new
			userSalary.user_id = list[:user_id]
			userSalary.currency = list[:currency]
			userSalary.amount = (list[:amount]).round
			userSalary.salary_component_id = list[:salary_component_id]
			userSalary.salary_date = list[:salary_date]
				if !userSalary.save()
					errorMsg += userSalary.errors.full_messages.join('\n')
				end
		end
		errorMsg
	end

	def payroll_to_csv(payrollentries)
		decimal_separator = l(:general_csv_decimal_separator)
		grandBasicTotal = ""
		grandAllowanceTotal = ""
		grandDeductionTotal = ""
		grandGrossTotal = ""
		grandNetTotal = ""
		currency = ""
		export = Redmine::Export::CSV.generate do |csv|
		  # csv header fields
			headers = [l(:field_user),
					 l(:field_join_date),
					 l(:label_salarydate),
					 l(:label_basic),
					 l(:label_allowances),
					 l(:label_deduction),
					 l(:label_gross),
					 l(:label_net),
					 ]
			csv << headers.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, l(:general_csv_encoding))}
			payrollentries.each do |key, payroll_data|
				currency =  payroll_data[:currency]
				gross = payroll_data[:BT].to_i+ payroll_data[:AT].to_i
				net = gross  - payroll_data[:DT].to_i unless gross.blank?
				grandBasicTotal = grandBasicTotal.to_i + payroll_data[:BT].to_i
				grandAllowanceTotal = grandAllowanceTotal.to_i + payroll_data[:AT].to_i
				grandDeductionTotal = grandDeductionTotal.to_i + payroll_data[:DT].to_i
				grandGrossTotal = grandGrossTotal.to_i + gross.to_i
				grandNetTotal = grandNetTotal.to_i + net.to_i
				
				dataArr = [payroll_data[:firstname].to_s + " " + payroll_data[:lastname].to_s, payroll_data[:joinDate], payroll_data[:salDate], currency +
				 payroll_data[:BT].to_s, currency + payroll_data[:AT].to_s, currency + payroll_data[:DT].to_s, currency + gross.to_s , currency + net.to_s]
				
				csv << dataArr.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, l(:general_csv_encoding))}
			end
				totalArr = ["","", "Total", currency + grandBasicTotal.to_s, currency + grandAllowanceTotal.to_s, currency + grandDeductionTotal.to_s,
					currency + grandGrossTotal.to_s, currency + grandNetTotal.to_s ]
			  csv << totalArr.collect {|t| Redmine::CodesetUtil.from_utf8(t.to_s, l(:general_csv_encoding))}
		end
		export
  end
end