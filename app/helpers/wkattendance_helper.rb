module WkattendanceHelper	
	#include QueriesHelper
	
	def time_expense_tabs
		tabs = [
				{:name => 'wktime', :partial => 'wktime/tab_content', :label => :label_wktime},
				{:name => 'wkexpense', :partial => 'wktime/tab_content', :label => :label_wkexpense},
				{:name => 'wkattendance', :partial => 'wktime/tab_content', :label => :label_wk_attendance}
			   ]	
	end		

end
