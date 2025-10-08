module SendPatch::QueriesControllerPatch
	def self.included(base)
		base.class_eval do

			def redirect_to_wk_expense_entry_query(options)
			  redirect_to _time_entries_path(@project, nil, options)
			end

			def redirect_to_wk_material_entry_query(options)
			  redirect_to _time_entries_path(@project, nil, options)
			end

		end
	end
end