module WkpayrollHelper
	include WktimeHelper
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
	
	def savePayrollSettings(settingsValue)
		sval = Array.new	
		settingsValue.select {|key,value| 
		if !value.blank?
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
				if key.to_s == 'payroll_deleted_ids'
					wksalaryComponents.destroy()
				else
					wksalaryComponents.save()
				end
			end
		end		
		}
    end
end
