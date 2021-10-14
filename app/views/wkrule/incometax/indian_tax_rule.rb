module PayrollTax
	include WkpayrollHelper

	def getIncomeTaxSlab
		# Income tax slab for FY 2020-21
		taxSlab= {
			0..250000 => 0,
			250001..500000 => 0.05,
			500001..750000 => 0.1, 
			750001..1000000 => 0.15, 
			1000001..1250000 => 0.2,             
			1250001..1500000 => 0.25,
			1500001...Float::INFINITY => 0.3
		}
        taxSlab
	end    

	def getSurchargeTaxSlab
		surchargeTax= {
			5000001..10000000 => 0.1,
			10000001..20000000 => 0.15,
			20000001..50000000 => 0.25,
			50000001...Float::INFINITY => 0.37
		}
		surchargeTax
	end

	def getIncomeLimit
		return 500000
	end

	def getSurchargeData
		surcharge = []
		return surcharge << {limit: 5000000, income: 1237500}
	end

	def getCessRate
		return 0.04
	end
	
	def saveTaxComponent(settings)
        taxSettings = WkSetting.where("name = 'tax_settings'" ).first
        taxSettings = WkSetting.new if taxSettings.blank?
        taxSettings.name = 'tax_settings'
        taxSettings.value = settings.to_json
        taxSettings.save
	end

	def getFinancialDates
		date = {}
		financialStartMonth = getFinancialStart
		start_year = Date.today.month < 4 ? (Date.today.year)-1 : Date.today.year
		date['start_date'] = ('01-' + financialStartMonth + '-' + start_year.to_s).to_date
		date['end_date'] = (date['start_date'] + 1.year) - 1.day
		date
	end

	def getUserSalaries(userIds)
		financialDate = getFinancialDates
		@salaries = WkSalary.getUserSalaries(financialDate['start_date'], financialDate['end_date'])
		@userSalaryHash = getUserSalaryHash(userIds, financialDate['end_date'], 'userSetting')
	end

	def getAnnualComponent(userId)
		financialPeriod = Array.new
		financialDate = getFinancialDates
		user = WkUser.where("user_id = ?", userId).first
		unless user&.join_date.blank?
			userDate = (user.join_date.to_date + 1.month).at_beginning_of_month
			if financialDate['start_date'] < userDate
				financialDate['start_date'] = userDate
			end
		end
		lastDate = financialDate['start_date']
		until lastDate > financialDate['end_date']
			financialPeriod << [lastDate, (lastDate + 1.months) -1.days]
			lastDate = lastDate + 1.months
		end

		component = Hash.new
    	taxComp =  getTaxSettings('tax_settings').blank? ? {} : JSON.parse(getTaxSettings('tax_settings'))
		financialPeriod.each do |start_date, end_date|
			monthSalary = @salaries.where("user_id = ? and salary_date between ? and ?", userId, start_date, end_date)
			if monthSalary.present?
				taxComp.each do |name, id|
					component[name] ||= 0
					if name == "annual_gross"
						component[name] += monthSalary.first.amount if id.present?
					end
				end
			else
				taxComp.each do |name, id|
					component[name] ||= 0
					component[name] += @userSalaryHash[userId.to_i][id.to_i].to_f if ["annual_gross"].include?(name) &&
							id.present? && @userSalaryHash.present? && @userSalaryHash[userId.to_i][id.to_i].present?
				end
			end
		end
		component
	end

	# Calculate Monthly Tax Amount
	def calculate_tax(userId)
		compVal = getAnnualComponent(userId)
		financialDate = getFinancialDates
		# Income tax slab for Fy 2020-21
		monthCount =((12 * (financialDate['end_date'].year - financialDate['start_date'].year) + financialDate['end_date'].month - financialDate['start_date'].month).abs) + 1
		taxIncome = compVal['annual_gross'].to_f
		taxAmount = 0
		getIncomeTaxSlab.each do |range, rate|
			taxAmount += rate * (range.last - (range.first-1)) if taxIncome > range.last
			taxAmount += rate * (taxIncome - (range.first-1)) if range === taxIncome && taxIncome > getIncomeLimit
		end

		#SurchargTax Calculation
		getSurchargeData.each do |data|
			if taxIncome > data[:limit]
				surchargeTax = 0
				getSurchargeTaxSlab.each do |range, rate|
					surchargeTax = taxAmount + (rate * taxAmount) if range === taxIncome
				end
				#Marginal Relief
				incSalary = taxIncome - data[:limit]
				incTax = surchargeTax - data[:income]
				if incTax > incSalary
					surcharge = taxAmount - data[:income]
					surchargeTax = taxAmount + (incSalary - surcharge)
				end
				taxAmount = surchargeTax
			end
		end
		taxAmount += (taxAmount * getCessRate) #Cess Amount
		tdsID = getTaxSettings('income_tax').to_i
		tdsValue = WkSalary.where("user_id = ? and salary_component_id = ? and salary_date between ? and ? ", userId, tdsID, financialDate['start_date'], financialDate['end_date'] )
		if tdsValue.present?
			tdsAmt = tdsValue.sum(:amount)
			taxAmount = (taxAmount >= tdsAmt) ? taxAmount- tdsAmt : 0
			monthCount -= tdsValue.count
		end
		monthTax = (taxAmount / monthCount).to_f
		monthTax = (monthTax.blank? ||  monthTax.nan?) ? 0.0 : "%.2f" % monthTax
		monthTax
	end
end