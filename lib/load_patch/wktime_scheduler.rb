require 'rufus/scheduler'
module LoadPatch::WktimeScheduler
	Rails.application.config.after_initialize do
		if ActiveRecord::Base.connection.table_exists? "#{Setting.table_name}"
			if ActiveRecord::Base.connection.table_exists?("#{WkNotification.table_name}") && WkNotification.notify('nonSubmission')
				if (!Setting.plugin_redmine_wktime['wktime_use_approval_system'].blank? && Setting.plugin_redmine_wktime['wktime_use_approval_system'].to_i == 1)
					submissionDeadline = Setting.plugin_redmine_wktime['wktime_submission_deadline']
					hr = Setting.plugin_redmine_wktime['wktime_nonsub_sch_hr']
					min = Setting.plugin_redmine_wktime['wktime_nonsub_sch_min']
					scheduler = Rufus::Scheduler.new #changed from start_new to new to make compatible with latest version rufus scheduler 3.0.3
					if hr == '0' && min == '0'
						cronSt = "0 * * * #{submissionDeadline}"
					else
						cronSt = "#{min} #{hr} * * #{submissionDeadline}"
					end
					scheduler.cron cronSt do
						begin
							Rails.logger.info "==========Non submission mail job - Started=========="
							wktime_helper = Object.new.extend(WktimeHelper)
							wktime_helper.sendNonSubmissionMail()
						rescue Exception => e
							Rails.logger.info "Job failed: #{e.message}"
						end
					end
				end
			end

			if (!Setting.plugin_redmine_wktime['wktime_period_end_process'].blank? && Setting.plugin_redmine_wktime['wktime_period_end_process'].to_i == 1)
				scheduler2 = Rufus::Scheduler.new
				#Scheduler will run at 12:01 AM on 1st of every month
				cronSt = "01 00 01 * *"
				scheduler2.cron cronSt do
					begin
						Rails.logger.info "==========Attendance job - Started=========="
						wkattn_helper = Object.new.extend(WkattendanceHelper)
						wkattn_helper.populateWkUserLeaves(Date.today)
						Rails.logger.info "==========Attendance job - Completed=========="
					rescue Exception => e
						Rails.logger.info "Job failed: #{e.message}"
					end
				end
			end

			if (!Setting.plugin_redmine_wktime['wktime_auto_import'].blank? && Setting.plugin_redmine_wktime['wktime_auto_import'].to_i == 1)
				importScheduler = Rufus::Scheduler.new
				import_helper = Object.new.extend(WkimportattendanceHelper)
				intervalMin = import_helper.calcSchdulerInterval
				#Scheduler will run at every intervalMin
				importScheduler.every intervalMin do
					begin
						Rails.logger.info "==========Import Attendance - Started=========="
						filePath = Setting.plugin_redmine_wktime['wktime_file_to_import']
						# Sort the files by modified date ascending order
						sortedFilesArr = Dir.entries(filePath).sort_by { |x| File.mtime(filePath + "/" +  x) }
						sortedFilesArr.each do |filename|
							next if File.directory? filePath + "/" + filename
							isSuccess = import_helper.importAttendance(filePath + "/" + filename, true )
							if !Dir.exists?("Processed")
								FileUtils::mkdir_p filePath+'/Processed'#Dir.mkdir("Processed")
							end
							if isSuccess
								FileUtils.mv filePath + "/" + filename, filePath+'/Processed', :force => true
								Rails.logger.info("====== #{filename} moved processed directory=========")
							end
						end
					rescue Exception => e
						Rails.logger.error "Import failed: #{e.message}"
					end
				end
			end

			if (!Setting.plugin_redmine_wktime['wktime_auto_generate_salary'].blank? && Setting.plugin_redmine_wktime['wktime_auto_generate_salary'].to_i == 1)
				salaryScheduler = Rufus::Scheduler.new
				payperiod = Setting.plugin_redmine_wktime['wktime_pay_period']
				payDay = Setting.plugin_redmine_wktime['wktime_pay_day']
				if payperiod == 'm'
					#Scheduler will run at 12:01 AM on 1st of every month
					cronSt = "01 00 01 * *"
				else
					#Scheduler will run at 12:01 AM on payDay of every week
					cronSt = "01 00 * * #{payDay}"
				end
				salaryScheduler.cron cronSt do
					begin
						currentMonthStart = Date.civil(Date.today.year, Date.today.month, Date.today.day)
						runJob = true
						# payperiod is bi-weekly then run scheduler every two weeks
						if payperiod == 'bw'
							salaryCount = WkSalary.where("salary_date between '#{currentMonthStart-14}' and '#{currentMonthStart-1}'").count
							runJob = false if salaryCount > 0
						end
						if runJob
							Rails.logger.info "==========Payroll job - Started=========="
							wkpayroll_helper = Object.new.extend(WkpayrollHelper)
							errorMsg = wkpayroll_helper.generateSalaries(nil,currentMonthStart)
							Rails.logger.info "===== Payroll generated Successfully ====="
						end
					rescue Exception => e
						Rails.logger.info "Job failed: #{e.message}"
					end
				end
			end

			if (!Setting.plugin_redmine_wktime['wktime_auto_generate_invoice'].blank? && Setting.plugin_redmine_wktime['wktime_auto_generate_invoice'].to_i == 1)
				invoiceScheduler = Rufus::Scheduler.new
				invPeriod = Setting.plugin_redmine_wktime['wktime_generate_invoice_period']
				invDay = Setting.plugin_redmine_wktime['wktime_generate_invoice_day']
				genInvFrom = Setting.plugin_redmine_wktime['wktime_generate_invoice_from'].to_date
				if invPeriod == 'm' || invPeriod == 'q'
					#Scheduler will run at 12:01 AM on 1st of every month
					cronSt = "01 00 01 * *"
				else
					#Scheduler will run at 12:01 AM on invDay of every week
					cronSt = "01 00 * * #{invDay.blank? ? 0 : invDay}"
				end
				invoiceScheduler.cron cronSt do
					begin
						invoicePeriod = nil
						fromDate = nil
						currentMonthStart = Date.civil(Date.today.year, Date.today.month, Date.today.day)
						runJob = true
						case invPeriod
							when 'q'
							fromDate = currentMonthStart<<4 < genInvFrom ? genInvFrom : currentMonthStart<<4
							#Scheduler will run at 12:01 AM on 1st of every April, July, October and January months
							runJob = false if (currentMonthStart.month%3)-1 > 0
							when 'w'
							#Scheduler will run at 12:01 AM on invDay of every week
							fromDate = currentMonthStart-7 < genInvFrom ? genInvFrom : currentMonthStart-7
							when 'bw'
							invoiceCount = WkInvoice.where("invoice_date between '#{currentMonthStart-14}' and '#{currentMonthStart-1}'").count
							runJob = false if invoiceCount > 0
							fromDate = currentMonthStart-14 < genInvFrom ? genInvFrom : currentMonthStart-14
							else
							#Scheduler will run at 12:01 AM on 1st of every month
							fromDate = (currentMonthStart-1).beginning_of_month < genInvFrom ? genInvFrom : (currentMonthStart-1).beginning_of_month
						end
						invoicePeriod = [fromDate, currentMonthStart-1]
						if runJob
							Rails.logger.info "==========Invoice job - Started=========="
							invoiceHelper = Object.new.extend(WkinvoiceHelper)
							allAccProjets = WkAccountProject.all
							errorMsg = nil
							allAccProjets.each do |accProj|
								errorMsg = invoiceHelper.generateInvoices(accProj, nil, currentMonthStart, invoicePeriod)#account.id
							end
							if errorMsg.blank?
								Rails.logger.info "===== Invoice generated Successfully ====="
							else
								if errorMsg.is_a?(Hash)
									Rails.logger.info "===== Invoice generated Successfully ====="
									Rails.logger.info "===== Job failed: #{errorMsg['trans']} ====="
								else
									Rails.logger.info "===== Job failed: #{errorMsg} ====="
								end
							end
						end
					rescue Exception => e
						Rails.logger.info "Job failed: #{e.message}"
					end
				end
			end

			if (!Setting.plugin_redmine_wktime['auto_apply_depreciation'].blank? && Setting.plugin_redmine_wktime['auto_apply_depreciation'].to_i == 1)
				deprScheduler = Rufus::Scheduler.new
				wkpayroll_helper = Object.new.extend(WkpayrollHelper)
				wkinventory_helper = Object.new.extend(WkinventoryHelper)
				financialStart = wkpayroll_helper.getFinancialStart.to_i
				depreciationFreq = wkinventory_helper.getFrequencyMonth(Setting.plugin_redmine_wktime['wktime_depreciation_frequency'])
				#Scheduler will run at 12:01 AM on 1st of every month
				cronSt = "01 00 01 * *"
				deprScheduler.cron cronSt do
					begin
						unless (( financialStart - Date.today.month + 12)%depreciationFreq) > 0
							Rails.logger.info "==========Depreciation job - Started=========="
							depreciation_helper = Object.new.extend(WkassetdepreciationHelper)
							errorMsg = depreciation_helper.previewOrSaveDepreciation(Date.today - 1, Date.today - 1, nil, false)
							Rails.logger.info "===== Depreciation applied Successfully ====="
						end
					rescue Exception => e
						Rails.logger.info "Job failed: #{e.message}"
					end
				end
			end

			if (!Setting.plugin_redmine_wktime['wk_auto_shift_scheduling'].blank? && Setting.plugin_redmine_wktime['wk_auto_shift_scheduling'].to_i == 1)
				shiftschedular = Rufus::Scheduler.new
				#Scheduler will run at 12:01 AM on 1st of every month
				cronSt = "01 00 01 * *"
				shiftschedular.cron cronSt do
					begin
						Rails.logger.info "========== Shift Scheduling job - Started=========="
						scheduling_helper = Object.new.extend(WkschedulingHelper)
						scheduling_helper.autoShiftScheduling
						Rails.logger.info "==========  Shift Scheduling job - Finished=========="
					rescue Exception => e
						Rails.logger.info "Job failed: #{e.message}"
					end
				end
			end

			if (Setting.plugin_redmine_wktime['activity_remainder_mail'].present? && Setting.plugin_redmine_wktime['activity_remainder_mail'].to_i == 1)
				crmact_scheduler = Rufus::Scheduler.new
				#Scheduler will run at 12:01 AM daily
				cronSt = "01 00 * * *"
				crmact_scheduler.cron cronSt do
					begin
						Rails.logger.info "========== Activity mail job - Started==========="
						wkcrmActivity_helper = Object.new.extend(WkcrmactivityHelper)
						wkcrmActivity_helper.activity_reminder_mail()
						Rails.logger.info "==========  Activity mail job - Finished=========="
					rescue Exception => e
						Rails.logger.info "Job failed: #{e.message}"
					end
				end
			end
		end
		rescue => e
			Rails.logger.error e.message
	end
end