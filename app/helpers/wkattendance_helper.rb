module WkattendanceHelper	
	#include QueriesHelper
	
	def time_expense_tabs
		tabs = [
				{:name => 'wktime', :partial => 'wktime/tab_content', :label => :label_wktime},
				{:name => 'wkexpense', :partial => 'wktime/tab_content', :label => :label_wkexpense},
				{:name => 'wkattendance', :partial => 'wktime/tab_content', :label => :label_wk_attendance},
				{:name => 'wkattnreport', :partial => 'wktime/tab_content', :label => :label_report_plural}
			   ]	
	end	

	def options_for_period_select(value)
		options_for_select([
							[l(:label_this_month), 'current_month'],
							[l(:label_last_month), 'last_month']],
							value.blank? ? 'current_month' : value)
	end	

end
