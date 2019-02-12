# module SettingsControllerPatch
	# def self.included(base)
		# base.class_eval do
			# def plugin
				# @plugin = Redmine::Plugin.find(params[:id])
				# unless @plugin.configurable?
					# render_404
				# return
				# end
	# # ============= ERPmine_patch Redmine 4.0  =====================				
				# payrollValues = salaryComponentsHashVal if @plugin.id.to_s == "redmine_wktime"
	# # =====================	
				# if request.post?
					# setting = params[:settings] ? params[:settings].permit!.to_h : {}
					# Setting.send "plugin_#{@plugin.id}=", setting
	# # ============= ERPmine_patch Redmine 4.0  =====================					
					# saveSalaryComponents(payrollValues) if @plugin.id.to_s == "redmine_wktime"
	# # =====================					
					# flash[:notice] = l(:notice_successful_update)
					# redirect_to plugin_settings_path(@plugin)
				# else
					# @partial = @plugin.settings[:partial]
					# @settings = Setting.send "plugin_#{@plugin.id}"
	# # ============= ERPmine_patch Redmine 4.0  =====================					
					# retrieveSalarayComponents if @plugin.id.to_s == "redmine_wktime"
	# # =====================					
				# end
				# rescue Redmine::PluginNotFound
					# render_404
			# end
			
	# # ============= ERPmine_patch Redmine 4.0  =====================		
			# def salaryComponentsHashVal			
				# settinghash = Hash.new()
				# payrollValues = Hash.new()
				# settinghash = params[:settings]		
				# if !settinghash.blank? 
					# payrollValues[:basic] = settinghash["wktime_payroll_basic"]
					# payrollValues[:allowances] = settinghash["wktime_payroll_allowances"]
					# payrollValues[:deduction] = settinghash["wktime_payroll_deduction"]			
					# payrollValues[:payroll_deleted_ids] = settinghash["payroll_deleted_ids"]
					# settinghash.delete("wktime_payroll_basic") 
					# settinghash.delete("wktime_payroll_allowances") 
					# settinghash.delete("wktime_payroll_deduction") 
					# settinghash.delete("payroll_deleted_ids")
					# params[:settings] = settinghash
				# end	
				# payrollValues
			# end
			
			# def saveSalaryComponents(payrollValues)
				# wkpayroll_helper = Object.new.extend(WkpayrollHelper)
				# wkpayroll_helper.savePayrollSettings(payrollValues)
			# end
			
			# def retrieveSalarayComponents
				# dep_list = WkSalaryComponents.order('name')
				# basic = Array.new
				# allowance = Array.new
				# deduction = Array.new
				# hashval = Hash.new()
				# unless dep_list.blank?
					# dep_list.each do |list| 
					# basic = [list.id.to_s + '|' + list.name + '|' + list.salary_type + '|' + list.factor.to_s + '|' + list.ledger_id.to_s ]  if list.component_type == 'b'	
					# allowance = allowance << list.id.to_s + '|' + list.name+'|'+list.frequency.to_s+'|'+ (list.start_date).to_s+'|'+(list.dependent_id).to_s+'|'+list.factor.to_s + '|' + list.ledger_id.to_s	if list.component_type == 'a'
					# deduction = deduction << list.id.to_s + '|' + list.name + '|' + list.frequency.to_s + '|' + (list.start_date).to_s + '|' + (list.dependent_id).to_s + '|' + (list.factor).to_s + '|' + list.ledger_id.to_s if list.component_type == 'd'
						
					# end
				# end
				# hashval["wktime_payroll_basic"] = basic
				# hashval["wktime_payroll_allowances"] = allowance
				# hashval["wktime_payroll_deduction"] = deduction
				# @settings.merge!(hashval)
			# end
	# # =====================			
			
			
		# end
	# end
# end