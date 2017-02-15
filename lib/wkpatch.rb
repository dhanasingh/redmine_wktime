module WkreportControllerPatch
	def self.included(base)
		base.send(:include)
		
		base.class_eval do
			def report1
				#patch_report
				#Rails.logger.info("===============================")
				#Rails.logger.info("#{Redmine::Utils.relative_url_root}")
				#File.open("../redmine_wktime/lib/report_params.txt", "r") do |f|
				#  f.each_line do |line|
				#	puts line
				#  end
				#end
				#Rails.logger.info("===============================")
				#Rails.logger.info("#{@report_params}")
				if params[:report_type] == 'attendance_report'
					reportattn(false)
				elsif params[:report_type] == 'spent_time_report'
					reportattn(true)
				elsif params[:report_type] == 'report_time'
					redirect_to action: 'time_rpt', controller: 'wktime'				
				elsif params[:report_type] == 'report_expense'
					redirect_to :action => 'time_rpt', :controller => 'wkexpense'
				elsif params[:report_type] == 'payslip_rpt'
					redirect_to action: 'payslip_rpt', controller: 'wkpayroll'
				elsif params[:report_type] == 'payroll_rpt'
					redirect_to action: 'payroll_rpt', controller: 'wkpayroll'
				elsif params[:report_type] == 'pl_rpt'
					redirect_to action: 'pl_rpt', controller: 'wkaccounting'
				elsif params[:report_type] == 'balance_sheet'
					redirect_to action: 'balance_sheet', controller: 'wkaccounting'
				elsif params[:report_type] == 'lead_conv_rpt'
					redirect_to action: 'lead_conv_rpt', controller: 'wkcrm'
				elsif params[:report_type] == 'sales_act_rpt'
					redirect_to action: 'sales_act_rpt', controller: 'wkcrm'
				end
			end
		end
	end
end