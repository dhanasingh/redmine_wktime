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

	def generateSalaries(userIds, salaryDate)
		@payrollList = Array.new
		deleteWkSalaries(userIds, salaryDate)
		userSalaryHash = getUserSalaryHash(userIds,salaryDate)
		currency = Setting.plugin_redmine_wktime['wktime_currency']
		resMsg = Hash.new
		unless userSalaryHash.blank?
			getPayrollData(userSalaryHash, salaryDate)
			resMsg[:e] = SavePayroll(@payrollList,userIds,salaryDate)
			resMsg[:n] = l(:notice_successful_update) if resMsg[:e].blank?
		else
			resMsg[:e] = l(:error_wktime_save_nothing)
		end

		if resMsg[:e].blank? && isChecked('salary_auto_post_gl')
			basicledger = WkSalaryComponents.where("component_type = 'b' and ledger_id is not null ").count
			if Setting.plugin_redmine_wktime['wktime_cr_ledger'].present? && basicledger.to_i != 0
				resMsg[:e] = generateGlTransaction(salaryDate)
			else
				resMsg[:e] =  l(:error_trans_msg)
			end
		end
		resMsg
	end

	def getPayrollData(userSalaryHash, salaryDate)
		currency = Setting.plugin_redmine_wktime['wktime_currency']
		userSalaryHash.each do |userId, salary|
			salary.each do |componentId, amount|
				@payrollList << {:user_id => userId, :salary_component_id => componentId, :amount => amount.round, :currency => currency, :salary_date => salaryDate}
			end
		 end
		 @payrollList
	end

	def getCalculatedFieldValue(user_id, salary_type, salaryDate)
		totals = Hash.new()
		if ["BT", "BAT", "AT", "ABA", "SBA"].include?(salary_type)
			# For basic total
			allowance_total = 0
			basic_total = 0
			@userSalCompHash.each do |key, userComp|
				userComp.factor ||= 0
				multiplier = getMultiplier(userComp, @payPeriod)
				basic_total += userComp.factor*multiplier if userComp.sc_component_type == 'b' &&
					userComp.user_id == user_id && userComp.factor.present?
			end
			totals['BT'] = basic_total

			# For allowance total
			@userSalCompHash.each do |key, userComp|
				next unless userComp.sc_component_type == 'a' && userComp.user_id == user_id
				userComp.factor ||= 0
				multiplier = getMultiplier(userComp, @payPeriod)
				factor = userComp.dependent_id.present? ? computeFactor(userComp.user_id, userComp.dependent_id, userComp.factor, multiplier) : userComp.factor*multiplier
				allowance_total = allowance_total + factor.to_f
				totals['AT'] = allowance_total
			end
			totals['BAT'] = totals['BT'] + totals['AT']

			# For Annual Gross and Semi Annual Gross
			if ["ABA", "SBA"].include?(salary_type)
				if salary_type == "SBA"
					toDate = salaryDate.last_month.end_of_month
					fromDate = salaryDate.beginning_of_month - 5.month
				else
					toDate = salaryDate.last_month.end_of_month
					fromDate = salaryDate.beginning_of_month - 11.month
				end
				wksalary = WkSalary.get_gross(user_id, fromDate, toDate)
				totals[salary_type] = totals['BAT'] + (wksalary.present? ? wksalary.map(&:gross_amount).first : 0)
			end
		end

		# For deduction total
		if salary_type == "DT"
			deduction_total = 0
			@userSalCompHash.each do |key, userComp|
				next unless userComp.sc_component_type == 'd' && userComp.user_id == user_id
				userComp.factor ||= 0
				multiplier = getMultiplier(userComp, @payPeriod)
				factor = userComp.dependent_id.present? ? computeFactor(userComp.user_id, userComp.dependent_id, userComp.factor, multiplier) : userComp.factor*multiplier
				deduction_total += factor if factor.present?
			end
			totals['DT'] = deduction_total
		end
		totals[salary_type]
	end

	def getUserSalaryHash(userIds, salaryDate, userSetting=nil)
		userSalaryHash = Hash.new()
		@payPeriod = getPayPeriod(salaryDate)
		terminateCond = "(wu.termination_date is null or wu.termination_date >= '#{@payPeriod[0]}') and " if userSetting.blank?
		reimbursProjectIds =  getReimburseProjects
		@reimburseID = WkSalaryComponents.getReimburseID
		@reimburse = WkExpenseEntry.getReimburse(reimbursProjectIds) if reimbursProjectIds.length > 0
		queryStr = getUserSalaryQueryStr + " Where "+terminateCond.to_s+"sc.id is not null" + get_comp_cond('u')
		unless userIds.blank?
			@queryStr = queryStr + " and u.id in (#{userIds}) "
		else
			@queryStr = queryStr + " and u.type = 'User'"
		end
		queryStr = @queryStr  + " order by u.id, sc_component_type, sc_salary_type"
		@userSalaries = WkSalaryComponents.find_by_sql(queryStr)
		@userSalCompHash = Hash.new()

		#Obtain dependent id and factor of b, a and c components
		@userSalaries.each do |salComp|
			if ["b", "a"].include?(salComp.sc_component_type)
				returnVal = getSalCompDep(salComp.id, salComp.user_id)
				salComp.dependent_id = returnVal[0]
				salComp.factor = returnVal[1]
				@userSalCompHash[salComp.sc_id.to_s + '_' + salComp.user_id.to_s] = salComp
			end

			if salComp.sc_component_type == "c" && salComp.sc_salary_type != "DT"
				total = getCalculatedFieldValue(salComp.user_id, salComp.sc_salary_type, salaryDate)
				salComp.factor = total
				@userSalCompHash[salComp.sc_id.to_s + '_' + salComp.user_id.to_s] = salComp
			end

			if salComp.sc_component_type == "d"
				returnVal = getSalCompDep(salComp.id, salComp.user_id)
				salComp.dependent_id = returnVal[0]
				salComp.factor = returnVal[1]
				@userSalCompHash[salComp.sc_id.to_s + '_' + salComp.user_id.to_s] = salComp
			end

			if salComp.sc_component_type == "r"
				amount = @reimburse.where({user_id: salComp.user_id})&.sum(:amount) || 0 if @reimburse.present?
				salComp.factor = amount
				@userSalCompHash[salComp.sc_id.to_s + '_' + salComp.user_id.to_s] = salComp
			end
		end

		#For Dependent Total
		@userSalaries.each do |salComp|
			if salComp.sc_component_type == "c" && salComp.sc_salary_type == "DT"
				total = getCalculatedFieldValue(salComp.user_id, salComp.sc_salary_type, salaryDate)
				salComp.factor = total
				@userSalCompHash[salComp.sc_id.to_s + '_' + salComp.user_id.to_s] = salComp
			end
		end

		# lastUserId = -1
		# multiplier = 1.0
		@userSalaries.each do |entry|
			isAddSalComp = isAddCompToSal(entry,@payPeriod)
			if isAddSalComp && entry.factor.present?
				# if lastUserId != entry.user_id
					multiplier = getMultiplier(entry, @payPeriod)
				# 	lastUserId = entry.user_id
				# end
				userSalaryHash[entry.user_id][entry.sc_id] = 0 if userSalaryHash[entry.user_id].present?
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
		sqlStr = "SELECT sc.id, sc.id as sc_id, sc.name as sc_name, sc.component_type as sc_component_type,
				sc.frequency as sc_frequency, sc.start_date as sc_start_date, sc.salary_type as sc_salary_type, wu.termination_date,
				usc.factor as usc_factor, usc.dependent_id as usc_dependent_id, usc.salary_component_id as salary_component_id,
				usc.id as user_salary_component_id, u.id as user_id, u.firstname, u.lastname, usc.factor, usc.dependent_id, usc.salary_type as usc_salary_type
			FROM users u
			left join wk_salary_components sc on (1 = 1) " + get_comp_cond('sc') + "
			left join wk_user_salary_components usc on (sc.id = usc.salary_component_id and  usc.user_id = u.id) " + get_comp_cond('usc') + "
			left join wk_users wu on u.id = wu.user_id "+ get_comp_cond('wu')
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

	def getMultiplier(entry, payPeriod)
		if (entry&.usc_salary_type || entry.sc_salary_type) == 'h'
			multiplier = getWorkedHours(entry.user_id, payPeriod[0], payPeriod[1])
		else
			multiplier = 1.0
			terminationDate = nil
			if !entry.termination_date.blank? && entry.termination_date.to_date.between?(payPeriod[0],payPeriod[1])
				terminationDate = entry.termination_date.to_date
			end
			multiplier = computeProrate(payPeriod,terminationDate,entry.user_id, entry.sc_component_type)
		end
		multiplier
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
	def computeProrate(payPeriod, terminationDate,userId, component_type)
		# Last worked day by the user on the particular payPeriod
		lastWorkDateByUser = terminationDate.blank? ? payPeriod[1] : terminationDate
		multiplier = ["b", "a"].include?(component_type) ? ((getWorkingDaysCount(payPeriod[0],lastWorkDateByUser) - getLossOfPayDays(payPeriod,userId)) / getWorkingDaysCount(payPeriod[0],payPeriod[1])) : 1
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

	def computeFactor(userId, dependentId, factor, multiplier, isSalCompCond = false)
		salEntry = @userSalCompHash[dependentId.to_s + '_' + userId.to_s]
		if isSalCompCond
			factor = salEntry.present? ? salEntry.factor : 0
		else
			factor = factor*(salEntry.factor.blank? ? 0 : salEntry.factor)*getMultiplier(salEntry, @payPeriod)
		end
		if salEntry&.dependent_id.present?
			factor = computeFactor(userId, salEntry.dependent_id, factor, multiplier)
		end
		factor
	end

	def deleteWkSalaries(userId, salaryDate)
		wkSalaries = WkSalary.where("user_id in (#{userId}) ").where(salary_date: salaryDate)
		reimburseID = WkSalaryComponents.getReimburseID
		if reimburseID
			salaryId = wkSalaries.where(salary_component_id: reimburseID).pluck(:id)
			WkExpenseEntry.where({payroll_id: salaryId}).each {|s| s.update_attribute(:payroll_id, nil)} if salaryId
		end
		if !(userId.blank? || salaryDate.blank?)
			wkSalaries.delete_all
		elsif !salaryDate.blank?
			WkSalary.where(salary_date: salaryDate).delete_all
		elsif !userId.blank?
			WkSalary.where("user_id in (#{userId}) ").delete_all
		else
			WkSalary.delete_all
		end
	end

	def savePayrollSettings(settingsValue)
		dval = 	Array.new
		settingsValue.select {|key,value|
			if !value.blank?
				if key.to_s == 'dep_del_ids'
					dval = value.split('|')
					WkSalCompDependent.where(:id => dval.map(&:to_i)).destroy_all
				elsif key.to_s == 'cond_del_ids'
					dval = value.split('|')
					WkSalCompCondition.where(:id => dval.map(&:to_i)).destroy_all
				elsif key.to_s == 'comp_del_ids'
					dval = value.split('|')
					WkSalaryComponents.where(:id => dval.map(&:to_i)).destroy_all
				else
					for i in 0..value.length-1
						componentCond = Array.new
						wkcompDep = Array.new
						comps = value[i].split('|')
						if !comps[0].blank?
							wksalaryComps =  WkSalaryComponents.find(comps[0])
						else
							wksalaryComps = WkSalaryComponents.new
						end
						if key.to_s == 'basic'
							wksalaryComps.name = comps[1]
							wksalaryComps.component_type = 'b'
							wksalaryComps.salary_type = comps[2]
							wksalaryComps.ledger_id = comps[5]
							wksalaryComps.salary_comp_deps_attributes = [{id: checkEmpty(comps[3]), dependent_id: nil,
								factor: comps[4], factor_op: "EQ"}]
						elsif key.to_s == 'reimburse'
							wksalaryComps.name = comps[1]
							wksalaryComps.ledger_id = comps[2]
							wksalaryComps.component_type = 'r'
						elsif key.to_s != 'Calculated_Fields'
							wksalaryComps.name = comps[1]
							wksalaryComps.frequency = comps[2]
							wksalaryComps.start_date = comps[3]
							wksalaryComps.component_type = key.to_s == 'allowances' ? 'a' : 'd'
							wksalaryComps.ledger_id = comps[4]
							if comps[5].present?
								strDepConds = comps[5].split("-")
								strDepConds.each do |strDep_cond|
									depCond = strDep_cond.split('_')
									wkcompCond = Hash.new
									if depCond[4] != "::::"
										compCond = depCond[4].split(":")
										wkcompCond = {id: checkEmpty(compCond[0]), lhs: compCond[1], operators: compCond[2], rhs: compCond[3],
											rhs2: compCond[4].present? ? compCond[4] : 0}
									end
									compDepSets = {id: checkEmpty(depCond[0]), dependent_id: depCond[1], factor: depCond[3],
										factor_op: depCond[2]}
									compDepSets[:salary_comp_cond_attributes] = wkcompCond if wkcompCond.present?
									wkcompDep << compDepSets
								end
								wksalaryComps.salary_comp_deps_attributes = wkcompDep if wkcompDep.present?
							end
						else
							wksalaryComps.name = comps[1]
							wksalaryComps.component_type = 'c'
							wksalaryComps.salary_type = comps[2]
						end
							wksalaryComps.save()
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
		glTransaction.trans_type = transTypeHash[Setting.plugin_redmine_wktime['wktime_cr_ledger'].to_i] == "BA" || transTypeHash[Setting.plugin_redmine_wktime['wktime_cr_ledger'].to_i] == "CS" ? "P" : "J"
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
			totalDebit = totalDebit + value.to_i if ['b', 'a', 'r'].include?(ledgersIdHash[key.to_i])
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
		sqlStr = getQueryStr + " where s.user_id = #{userid} and s.salary_date='#{salarydate}'" + get_comp_cond('s') + get_comp_cond('sc') + get_comp_cond('u')
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
		" left join wk_users wu on u.id = wu.user_id " + get_comp_cond('wu')
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
			l(:label_deduction_total) => "DT",
			l(:label_semi_ba_total) => "SBA",
			l(:label_annual_ba_total) => "ABA"
		}
	end

	def SavePayroll(payrollList,userIds,salaryDate)
		errorMsg = nil
		payrollList.each do |list|
			userSalary = WkSalary.new
			userSalary.user_id = list[:user_id]
			userSalary.currency = list[:currency]
			userSalary.amount = (list[:amount]).round
			userSalary.salary_component_id = list[:salary_component_id]
			userSalary.salary_date = list[:salary_date]
				if !userSalary.save()
					errorMsg = userSalary.errors.full_messages.join('\n')
				else
    				@reimburse&.where({user_id: list[:user_id]})&.each {|r| r.update_attribute(:payroll_id, userSalary.id)} if @reimburseID && (@reimburseID.to_i == list[:salary_component_id])
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
		reimbursementTotal = ""
		currency = ""
		export = Redmine::Export::CSV.generate do |csv|
		  # csv header fields
			headers = [l(:field_user),
					 l(:field_join_date),
					 l(:label_salarydate),
					 l(:label_basic),
					 l(:label_allowances),
					 l(:label_deduction),
					 l(:label_reimbursements),
					 l(:label_gross),
					 l(:label_net),
					 ]
			csv << headers.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, l(:general_csv_encoding))}
			payrollentries.each do |key, payroll_data|
				currency =  payroll_data[:currency]
				gross = payroll_data[:BT].to_i+ payroll_data[:AT].to_i
				reimbursement =  payroll_data[:RT].to_i
				net = gross  - payroll_data[:DT].to_i unless gross.blank?
				grandBasicTotal = grandBasicTotal.to_i + payroll_data[:BT].to_i
				grandAllowanceTotal = grandAllowanceTotal.to_i + payroll_data[:AT].to_i
				grandDeductionTotal = grandDeductionTotal.to_i + payroll_data[:DT].to_i
				grandGrossTotal = grandGrossTotal.to_i + gross.to_i
				grandNetTotal = grandNetTotal.to_i + net.to_i
				reimbursementTotal = reimbursementTotal.to_i + reimbursement.to_i

				dataArr = [payroll_data[:firstname].to_s + " " + payroll_data[:lastname].to_s, payroll_data[:joinDate], payroll_data[:salDate], currency +
				 payroll_data[:BT].to_s, currency + payroll_data[:AT].to_s, currency + payroll_data[:DT].to_s, currency + reimbursement.to_s, currency + gross.to_s , currency + net.to_s]

				csv << dataArr.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, l(:general_csv_encoding))}
			end
				totalArr = ["","", "Total", currency + grandBasicTotal.to_s, currency + grandAllowanceTotal.to_s, currency + grandDeductionTotal.to_s,
					currency + reimbursementTotal.to_s, currency + grandGrossTotal.to_s, currency + grandNetTotal.to_s ]
			  csv << totalArr.collect {|t| Redmine::CodesetUtil.from_utf8(t.to_s, l(:general_csv_encoding))}
		end
		export
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
		userList = userList.where("(LOWER(firstname) like LOWER('%#{params[:name]}%') or LOWER(lastname) like LOWER('%#{params[:name]}%'))") if params[:name].present?
		userList = userList.where("status = ?", params[:status]) if params[:status].present?
		userList
	end

	def getUsersAndGroups
		userList = get_group_members
		@groups = Group.where(type: "Group").sorted.all
		@members = Array.new
		userIds = Array.new
		userList.each do |users|
			@members << [users.name,users.id.to_s()]
			userIds << users.id
		end
		userIds
	end

	def getLogicalCond
		{
			"" => '',
			l(:label_equal) => "EQ",
			l(:label_less_than) => "LT",
			l(:label_greater_than) => "GT",
			l(:label_less_or_equal) => "LTE",
			l(:label_greater_or_equal) => "GTE",
			l(:label_between) => "BW"
		}
	end

	def compCondition(compCond, userID, salComp)
		returnVal = Array.new
		multiplier = getMultiplier(salComp, @payPeriod)
		lhs = computeFactor(userID, compCond.lhs, 0, multiplier, true)
		case compCond.operators
			when "EQ"
				cond = lhs == compCond.rhs
			when "LT"
				cond = lhs < compCond.rhs
			when "LTE"
				cond = lhs <= compCond.rhs
			when "GT"
				cond = lhs > compCond.rhs
			when "GTE"
				cond = lhs >= compCond.rhs
			when "BW"
				cond = compCond.rhs <= lhs && lhs <= compCond.rhs2
			else
				cond = true
		end
		cond
	end

	def getFactorOperators
		{
			l(:label_equal_operator) => "EQ",
			l(:label_multiplier) => "MUL"
		}
	end

	def getSalaryFrequency
		{
			'' => "",
			'm'  => l(:label_monthly),
			'q' =>  l(:label_quarterly),
			'sa' => l(:label_semi_annually),
			'a' => l(:label_annually)
		}
	end

	def getSalaryType
		{
			's' => l(:label_salaried),
			'h' =>  l(:label_hourly)
		}
	end

	def getLedgerNames
		WkLedger.order(:name).map{|p| [p.id.to_s, p.name]}.to_h
	end

	def getSalaryCompNames
		salary_comps = WkSalaryComponents.all.order('name')
		salaryCompNames = {"": ""}.merge(salary_comps.map{|p| [p.id.to_s, p.name]}.to_h)
	end

	def checkEmpty(val)
		val.present? ? val : nil
	end

	def getSalCompDep(salCompID, userID)
		queryStr = @queryStr + " AND sc.id = #{salCompID} AND u.id = #{userID} "
		salComp = WkSalaryComponents.find_by_sql(queryStr).first
		factor = 0
		dependentID = ''
		if salComp.factor.present?
			factor = salComp.factor
			dependentID = salComp.dependent_id
		else
			compDeps = salComp.salary_comp_deps
			compDeps.each do |comp_dep|
				compCond = comp_dep.salary_comp_cond
				if compCond.blank? || compCondition(compCond, salComp.user_id, salComp)
					factor = comp_dep.factor
					dependentID = comp_dep.dependent_id
				end
			end
		end
		[dependentID, factor]
	end

	def getTaxSettings(value)
		taxEntries = WkSetting.where({name: value}).all
		if value.is_a?(Array)
			taxSetting = {}
			taxEntries.each{|entry| taxSetting[entry.name] = entry.value}
			return taxSetting
		else
			return taxEntries&.first&.value || ''
		end
	end

	def get_tax_rule
		taxRule = []
		Dir["plugins/redmine_wktime/app/views/wkrule/incometax/_*"].each do |file|
			fileName = File.basename(file, ".html.erb")
			fileName.slice!(0)
			taxRule << [l(:"#{fileName}"), fileName]
		end
		taxRule.sort!
	end

	def getSalCompsByCompType(comp_type)
		if comp_type == 'settings_allowances' || comp_type == 'a'
			filterSalComps = WkSalaryComponents.where("salary_type in('BAT', 'AT', 'SBA', 'ABA', 'DT')").pluck(:id)
		else
			filterSalComps = WkSalaryComponents.where("salary_type in('DT')").pluck(:id)
		end
		filterSalComps
	end

	def filterSalComps(compEntry)
		salaryComponents = getSalaryComponentsArr
		salaryComponents = salaryComponents.reject{|name, id| name.include?(compEntry.sc_name.to_s) }
		filterSalComps = getSalCompsByCompType(compEntry.sc_component_type)
		if compEntry.sc_component_type == 'b'
			salaryComponents = [[ "", '-1']]
		else
			salaryComponents.delete_if {|c| filterSalComps.include?(c.last)}
		end
	end

	def saveTaxComponent(userIds)
		if isCalculateTax
			load("plugins/redmine_wktime/app/views/wkrule/incometax/#{getTaxSettings('tax_rule')}.rb")
			taxRule = Object.new.extend(PayrollTax)
			taxRule.getUserSalaries(userIds.join(','))
			userIds.each do |userId|
				taxAmount = taxRule.calculate_tax(userId)
				tdsID = getTaxSettings('income_tax').to_i
				userSalComp = WkUserSalaryComponents.where("user_id=? and salary_component_id=?", userId, tdsID).first
				userSalComp = WkUserSalaryComponents.new if userSalComp.blank?
				userSalComp.user_id = userId
				userSalComp.salary_component_id = tdsID
				userSalComp.factor = taxAmount
				userSalComp.save
			end
		end
	end

	def isCalculateTax
		taxSetting = getTaxSettings(['income_tax', 'tax_rule'])
		return taxSetting['income_tax'].present? && taxSetting['tax_rule'].present?
	end

	def getReimburseProjects
		projects = Project.active.all
		projectIds =  Setting.plugin_redmine_wktime['reimburse_projects'] || []
		projectIds.reject! {|id| id.to_s == "" } if projectIds.present?
		projectIds =  projects.pluck(:id) if projects.present? && projectIds.length == 0
		projectIds
	end

end