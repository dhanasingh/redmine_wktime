module WkdashboardHelper
	# Return the graphs with its type
	# key - graph name, value - graph type 
	def get_graphs_with_type
		{"clock_in_users_over_time" => "Bar",
		"expense_for_issues" => "Bar"}
	end
end
