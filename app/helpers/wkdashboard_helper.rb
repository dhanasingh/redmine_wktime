module WkdashboardHelper
	# Return the graphs with its type
	# key - graph name, value - graph type 
	include WkreportHelper
	include Redmine::I18n
  
   def get_graphs_yaml_path
	 files_array = []
	 Dir["plugins/redmine_wktime/app/views/wkdashboard/*.yml"].each do |f| 
		file_name = File.basename(f)	
		files_array << ["#{file_name}"] 
	 end   
   end
  
   def label_check(l_name)     
      I18n.t( l_name, default: l_name )
   end
	
	# def get_graphs_with_type
		# {"clock_in_users_over_time" => "Bar",
		# "expense_for_issues" => "Pie",
		# "lead_generation_vs_conversion" => "Line",
		# "invoice_vs_payment_per_month" => "Line",
		# "assests_per_month" => "Line",
		# "profit_loss_per_month" => "Line"}
	# end
	
	def options_for_period_select(value)
		options_for_select([
							[l(:label_this_week), 'current_week'],
							[l(:label_last_week), 'last_week'],
							[l(:label_this_month), 'current_month'],
							[l(:label_last_month), 'last_month'],
							[l(:label_this_year), 'current_year']],
							value.blank? ? 'current_week' : value)
	end
	
	def showDashboard
		!Setting.plugin_redmine_wktime['wktime_enable_dashboards_module'].blank? &&
			Setting.plugin_redmine_wktime['wktime_enable_dashboards_module'].to_i == 1
	end
end
