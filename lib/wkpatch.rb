module WkreportControllerPatch
	def self.included(base)
		base.send(:include)
		
		base.class_eval do
			def report
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
				elsif params[:report_type] == 'time_report'
					redirect_to action: 'time_rpt', controller: 'wktime'
					elsif params[:report_type] == 'payslip_report'
					redirect_to action: 'payslip_rpt', controller: 'wkpayroll'
					#paysliprpt
				elsif params[:report_type] == 'expense_report'
					redirect_to :action => 'time_rpt', :controller => 'wkexpense'
				end
			end
		end
	end
end