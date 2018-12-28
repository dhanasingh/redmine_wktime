module WkdashboardHelper
	# Return the graphs with its type
	# key - graph name, value - graph type 
	include WkreportHelper
	
	def get_graphs_with_type
		{"clock_in_users_over_time" => "Bar",
		"expense_for_issues" => "Pie",
		"lead_generation_vs_conversion" => "Line",
		"invoice_vs_payment_per_month" => "Line",
		"assests_per_month" => "Line",
		"profit_loss_per_month" => "Line"}
	end
	
	def showDashboard
		!Setting.plugin_redmine_wktime['wktime_enable_dashboards_module'].blank? &&
			Setting.plugin_redmine_wktime['wktime_enable_dashboards_module'].to_i == 1
	end
end
