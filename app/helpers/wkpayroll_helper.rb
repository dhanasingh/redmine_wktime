module WkpayrollHelper	
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
end
