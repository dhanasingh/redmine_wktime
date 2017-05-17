module WkreportControllerPatch2
	def self.included(base)
		base.send(:include)
		
		base.class_eval do
			def report_params
				@report_params = [
					['attendance_report', 'Attendance', 'wkreport', 'reportattn'],
					['report_time', 'Timesheet', 'wktime', 'time_rpt'],
					['payslip_rpt', 'Payslip', 'wkreport', 'payslip_rpt'],
					['report_expense', 'Expensesheet', 'wkexpense', 'time_rpt'],
					['pl_rpt', 'Profit & Loss A/c', 'wkaccounting', 'pl_rpt'],
					['balance_sheet', 'Balance Sheet', 'wkaccounting', 'balance_sheet'],
					['lead_conv_rpt', 'Lead Conversion', 'wkcrm', 'lead_conv_rpt'],
					['sales_act_rpt', 'Sales Activity', 'wkcrm', 'sales_act_rpt']
				]
			end
		end
	end
end

#['attendance_report', l(:report_attendance), 'wkreport', 'reportattn'],
#['report_time', l(:label_wk_timesheet), 'wktime', 'time_rpt'],
#['report_expense', l(:label_wk_expensesheet), 'wkexpense', 'time_rpt']	

#@report_params = [
					#[report_name, description, controller_name, method_name],
					#['attendance_report', 'Attendance', 'wkreport', 'reportattn'],
					#['report_time', 'Timesheet', 'wktime', 'time_rpt'],
					['report_expense', 'Expensesheet', 'wkexpense', 'time_rpt']				
				#]