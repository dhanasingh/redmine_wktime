require 'redmine'
require_dependency 'custom_fields_helper'
require 'wkpatch'
require 'report_params'
require_dependency '../lib/redmine/menu_manager'
require 'fileutils'


# redmine only differs between project_menu and application_menu! but we want to display the
# time_tracker submenu only if the plugin specific controllers are called
module Redmine::MenuManager::MenuHelper
  def display_main_menu?(project)
    Redmine::MenuManager.items(menu_name(project)).children.present?
  end

  def render_main_menu(project)
    render_menu(menu_name(project), project)
  end

  private

  def menu_name(project)
    if project && !project.new_record?
      :project_menu
    else
	  controllerArr = ["wktime", "wkexpense", "wkattendance", "wkreport", "wkpayroll",  "wkinvoice", "wkcrmaccount", "wkcontract", "wkaccountproject", "wktax", "wkgltransaction", "wkledger", "wklead", "wkopportunity", "wkcrmactivity", "wkcrmcontact", "wkcrmenumeration", "wkpayment", "wkexchangerate","wkpurchase","wkrfq","wkquote","wkpurchaseorder","wksupplierinvoice","wksupplierpayment","wksupplieraccount","wksuppliercontact" ]
	  externalMenus = call_hook :external_erpmine_menus
	   externalMenus = externalMenus.split(' ')
	  unless externalMenus.blank?
		controllerArr = controllerArr + externalMenus
	  end
      if controllerArr.include? params[:controller]
        :wktime_menu
      else
        :application_menu
      end
    end
  end
end

module WktimeHelperPatch
	def self.included(base)
		CustomFieldsHelper::CUSTOM_FIELDS_TABS << {:name => 'WktimeCustomField', :partial => 'custom_fields/index', :label => :label_wk_time}
	end	
end

module ProjectsControllerPatch
	def self.included(base)     
	  base.class_eval do
		def destroy	
			 @project_to_destroy = @project
			if api_request? || params[:confirm]
				wktime_helper = Object.new.extend(WktimeHelper)
				ret = wktime_helper.getStatus_Project_Issue(nil,@project_to_destroy.id)			
				if ret
					#render_403
					#return false
					 flash.now[:error] = l(:error_project_issue_associate)
					 return
				else
				  WkExpenseEntry.delete_all(['project_id = ?', @project_to_destroy.id])
				  @project_to_destroy.destroy
				  respond_to do |format|
					format.html { redirect_to admin_projects_path }
					format.api  { render_api_ok }
				  end
				end
			end
			# hide project in layout
			@project = nil
		end
	  end	  
	end	
end

module IssuesControllerPatch
 def self.included(base)     
  base.class_eval do
	def destroy		
		@hours = TimeEntry.where(:issue_id => @issues.map(&:id)).sum(:hours).to_f
		@amount = WkExpenseEntry.where(:issue_id => @issues.map(&:id)).sum(:amount).to_f
		if @hours > 0 || @amount > 0
			wktime_helper = Object.new.extend(WktimeHelper)
			issue_id = @issues.map(&:id)
		    ret = wktime_helper.getStatus_Project_Issue(issue_id[0],nil)
			if ret				
				flash.now[:error] = l(:error_project_issue_associate)
				return
			else
				case params[:todo]
				when 'destroy'
					WkExpenseEntry.delete_all(['issue_id = ?', issue_id[0]])
				when 'nullify'
					TimeEntry.where(['issue_id IN (?)', @issues]).update_all('issue_id = NULL')
					WkExpenseEntry.where(['issue_id IN (?)', @issues]).update_all('issue_id = NULL')
				when 'reassign'
					reassign_to = @project.issues.find_by_id(params[:reassign_to_id])
					if reassign_to.nil?
						flash.now[:error] = l(:error_issue_not_found_in_project)
						return
					else
						TimeEntry.where(['issue_id IN (?)', @issues]).update_all("issue_id = #{reassign_to.id}")
						WkExpenseEntry.where(['issue_id IN (?)', @issues]).update_all("issue_id = #{reassign_to.id}")
					end
				else
					# display the destroy form if it's a user request
					return unless api_request?
				end
			end
		end
		@issues.each do |issue|
		  begin
		 
			issue.reload.destroy
		  rescue ::ActiveRecord::RecordNotFound # raised by #reload if issue no longer exists
			# nothing to do, issue was already deleted (eg. by a parent)
		  end
		end
		respond_to do |format|
		  format.html { redirect_back_or_default _project_issues_path(@project) }
		  format.api  { render_api_ok }
		end
	end
  end
 end
end
	
module TimelogControllerPatch
	def self.included(base)
		base.send(:include)
		
		base.class_eval do
			def destroy
				wktime_helper = Object.new.extend(WktimeHelper)
				errMsg = ""
				destroyed = TimeEntry.transaction do
				@time_entries.each do |t|
					status = wktime_helper.getTimeEntryStatus(t.spent_on, t.user_id)	
					if !status.blank? && ('a' == status || 's' == status || 'l' == status)					
						 errMsg = "#{l(:error_time_entry_delete)}"
					end
					if errMsg.blank?
						unless (t.destroy && t.destroyed?)  
						  raise ActiveRecord::Rollback
						end
					end
				  end
				end

				respond_to do |format|
				  format.html {
					if errMsg.blank?
						if destroyed
						  flash[:notice] = l(:notice_successful_delete)
						else
						  flash[:error] = l(:notice_unable_delete_time_entry)
						end
					else
						flash[:error] = errMsg
					end
					redirect_back_or_default project_time_entries_path(@projects.first)
				  }
				  format.api  {
					if destroyed
					  render_api_ok
					else
					  render_validation_errors(@time_entries)
					end
				  }
				end
			end
		end
	end
end


module SettingsControllerPatch
	def self.included(base)
		base.send(:include)
		
		base.class_eval do
			def plugin
				wkpayroll_helper = Object.new.extend(WkpayrollHelper)
				settinghash = Hash.new()
				payrollValues = Hash.new()
				settinghash = params[:settings]		
				if !settinghash.blank? 
					payrollValues[:basic] = settinghash["wktime_payroll_basic"]
					payrollValues[:allowances] = settinghash["wktime_payroll_allowances"]
					payrollValues[:deduction] = settinghash["wktime_payroll_deduction"]			
					payrollValues[:payroll_deleted_ids] = settinghash["payroll_deleted_ids"]
					settinghash.delete("wktime_payroll_basic") 
					settinghash.delete("wktime_payroll_allowances") 
					settinghash.delete("wktime_payroll_deduction") 
					settinghash.delete("payroll_deleted_ids")
					params[:settings] = settinghash
				end	
				@plugin = Redmine::Plugin.find(params[:id])
				unless @plugin.configurable?
				  render_404
				  return
				end
				
				if request.post?
				  Setting.send "plugin_#{@plugin.id}=", params[:settings]
				  wkpayroll_helper.savePayrollSettings(payrollValues)
				  flash[:notice] = l(:notice_successful_update)
				  redirect_to plugin_settings_path(@plugin)
				else
				  @partial = @plugin.settings[:partial]			   
				  @settings = Setting.send "plugin_#{@plugin.id}"				
				  dep_list = WkSalaryComponents.order('name')
				  basic = Array.new
				  allowance = Array.new
				  deduction = Array.new
				  hashval = Hash.new()
				  unless dep_list.blank?
						dep_list.each do |list| 
						basic = [list.id.to_s + '|' + list.name + '|' + list.salary_type + '|' + list.factor.to_s + '|' + list.ledger_id.to_s ]  if list.component_type == 'b'	
						allowance = allowance << list.id.to_s + '|' + list.name+'|'+list.frequency.to_s+'|'+ (list.start_date).to_s+'|'+(list.dependent_id).to_s+'|'+list.factor.to_s + '|' + list.ledger_id.to_s	if list.component_type == 'a'
						deduction = deduction << list.id.to_s + '|' + list.name + '|' + list.frequency.to_s + '|' + (list.start_date).to_s + '|' + (list.dependent_id).to_s + '|' + (list.factor).to_s + '|' + list.ledger_id.to_s if list.component_type == 'd'
							
						end
					end
					hashval["wktime_payroll_basic"] = basic
					hashval["wktime_payroll_allowances"] = allowance
					hashval["wktime_payroll_deduction"] = deduction
					@settings.merge!(hashval)
				end				
			end
		end
	end
end
  
CustomFieldsHelper.send(:include, WktimeHelperPatch)
ProjectsController.send(:include, ProjectsControllerPatch)
IssuesController.send(:include, IssuesControllerPatch)
TimelogController.send(:include, TimelogControllerPatch)
SettingsController.send(:include, SettingsControllerPatch)

Redmine::Plugin.register :redmine_wktime do
  name 'ERPmine'
  author 'Adhi Software Pvt Ltd'
  description 'ERPmine is an ERP for Service Industries. It has the following modules: Time & Expense, Attendance, Payroll, CRM, Billing, Accounting and Purchasing'
  version '2.9.1'
  url 'http://www.redmine.org/plugins/wk-time'
  author_url 'http://www.adhisoftware.co.in/'
  
  settings(:partial => 'settings',
           :default => {
             'wktime_project_dd_width' => '150',
             'wktime_issue_dd_width' => '250',
             'wktime_actv_dd_width' => '75',
			 'wktime_closed_issue_ind' => '0',
			 'wktime_restr_min_hour' => '0',
			 'wktime_min_hour_day' => '0',
			 'wktime_restr_max_hour' => '0',
			 'wktime_max_hour_day' => '8',
			 'wktime_page_width' => '210',
			 'wktime_page_height' => '297',
			 'wktime_margin_top' => '20',
			 'wktime_margin_bottom' => '20',
			 'wktime_margin_left' => '10',
			 'wktime_margin_right' => '10',
			 'wktime_line_space' => '4',
			 'wktime_header_logo' => 'logo.jpg',
			 'wktime_work_time_header' => '0',
			 'wktime_allow_blank_issue' => '0',
			 'wktime_enter_comment_in_row' => '1',
 			 'wktime_use_detail_popup' => '0',
 			 'wktime_use_approval_system' => '0',
 			 'wktime_uuto_approve' => '0',			 
			 'wktime_submission_ack' => 'I Acknowledge that the hours entered are accurate to the best of my knowledge',
			 'wktime_enter_cf_in_row1' => '0',
			 'wktime_enter_cf_in_row2' => '0',
			 'wktime_enter_issue_as' =>'0',
			 'wktime_own_approval' => '0',
			 'wktime_previous_template_week' => '1',
			 'wkexpense_issues_filter_tracker' => ['0'],
			 'wktime_issues_filter_tracker' => ['0'],
			 'wktime_allow_user_filter_tracker' => '0',
			 'wktime_nonsub_mail_notification' => '0',
			 'wktime_nonsub_mail_message' => 'You are receiving this notification for timesheet non submission',
			 'wktime_submission_deadline' => '0',			
			 'wktime_nonsub_sch_hr' => '23',
			 'wktime_nonsub_sch_min' => '0',
			 'wkexpense_projects' => [''],			
			 'wktime_allow_filter_issue' => '0',
			 'wktime_account_groups' => ['0'],
			 'wktime_enable_clock_in_out' => '0',
			 'wktime_sick_leave_accrual' => '0',
			 'wktime_paid_leave_accrual' => '0',
			 'wktime_leave_accrual_after' => '0',
			 'wktime_default_work_time' => '8',
			 'wktime_restr_max_hour_week' => '0',
			 'wktime_max_hour_week' => '0',
			 'wktime_restr_min_hour_week' => '0',
			 'wktime_min_hour_week' => '0',
			 'wktime_enable_time_module' => '1',
			 'wktime_enable_expense_module' => '1',
			 'wktime_enable_report_module' => '1',
			 'wktime_enable_attendance_module' => '1',
			 'wktime_enable_payroll_module' => '1',
			 'wktime_auto_import' => '0',
			 'wktime_field_separator' => ['0'],
			 'wktime_field_wrapper'  => ['0'],
			 'wktime_field_encoding' => ['0'],
			 'wktime_field_datetime' => ['0'],
			 'wktime_avialable_fields' => ['0'],
			 'wktime_fields_in_file' => ['0'],
			 'wktime_auto_import_time_hr' => '23',
			 'wktime_auto_import_time_min' => '0',
			 'wktime_file_to_import' => '0',
			 'wktime_import_file_headers' => '0',
			 'wktime_enable_billing_module' => '0',
			 'wktime_auto_generate_invoice' => '0',
			 'wktime_generate_invoice_from' => nil,
			 'wktime_billing_groups' => '0',
			 'wktime_enable_accounting_module' => '0',
			 'wktime_accounting_group' => '0',
			 'wktime_accounting_admin' => '0',
			 'wktime_crm_group' => '0',
			 'wktime_crm_admin' => '0',
			 'wktime_minimum_working_days_for_accrual' => '11',
			 'wktime_enable_crm_module' => '0',
			 'wktime_enable_pur_module' => '0',
			 'wktime_pur_group' => '0',
			 'wktime_pur_admin' => '0'
  })  
	menu :top_menu, :wkTime, { :controller => 'wktime', :action => 'index' }, :caption => :label_erpmine, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission } 
  	
  project_module :time_tracking do
	permission :approve_time_entries,  {:wktime => [:update]}, :require => :member	
  end
  
  
  Redmine::MenuManager.map :wktime_menu do |menu|
	  menu.push :wktime, { :controller => 'wktime', :action => 'index' }, :caption => :label_te, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showTimeExpense }
	  menu.push :wkattendance, { :controller => 'wkattendance', :action => 'index' }, :caption => :report_attendance, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showAttendance}
	  menu.push :wkpayroll, { :controller => 'wkpayroll', :action => 'index' }, :caption => :label_payroll, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showPayroll }
	  menu.push :wklead, { :controller => 'wklead', :action => 'index' }, :caption => :label_crm, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showCRMModule }
	  menu.push :wkinvoice, { :controller => 'wkinvoice', :action => 'index' }, :caption => :label_wk_billing, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showBilling }
	  menu.push :wkgltransaction, { :controller => 'wkgltransaction', :action => 'index' }, :caption => :label_accounting, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showAccounting }
	  menu.push :wkrfq, { :controller => 'wkrfq', :action => 'index' }, :caption => :label_purchasing, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showPurchase }
	  menu.push :wkreport, { :controller => 'wkreport', :action => 'index' }, :caption => :label_report_plural, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showReports}	
	  menu.push :wkcrmenumeration, { :controller => 'wkcrmenumeration', :action => 'index' }, :caption => :label_settings, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && User.current.admin? }
	end	

end

WkreportController.send(:include, WkreportControllerPatch)

Rails.configuration.to_prepare do
	if ActiveRecord::Base.connection.table_exists? "#{Setting.table_name}"
		if (!Setting.plugin_redmine_wktime['wktime_nonsub_mail_notification'].blank? && Setting.plugin_redmine_wktime['wktime_nonsub_mail_notification'].to_i == 1)
		require 'rufus/scheduler'
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
		
		if (!Setting.plugin_redmine_wktime['wktime_enable_clock_in_out'].blank? && Setting.plugin_redmine_wktime['wktime_enable_clock_in_out'].to_i == 1)
			require 'rufus/scheduler'
			scheduler2 = Rufus::Scheduler.new
			#Scheduler will run at 12:01 AM on 1st of every month
			cronSt = "01 00 01 * *"
			scheduler2.cron cronSt do		
				begin
					Rails.logger.info "==========Attendance job - Started=========="			
					wkattn_helper = Object.new.extend(WkattendanceHelper)
					wkattn_helper.populateWkUserLeaves()
				rescue Exception => e
					Rails.logger.info "Job failed: #{e.message}"
				end
			end
		end
		
		if (!Setting.plugin_redmine_wktime['wktime_auto_import'].blank? && Setting.plugin_redmine_wktime['wktime_auto_import'].to_i == 1)
			require 'rufus/scheduler'
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
					Rails.logger.info "Import failed: #{e.message}"
				end
			end
		end
		
		if (!Setting.plugin_redmine_wktime['wktime_auto_generate_salary'].blank? && Setting.plugin_redmine_wktime['wktime_auto_generate_salary'].to_i == 1)
			require 'rufus/scheduler'
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
			require 'rufus/scheduler'
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
	end
end

class WktimeHook < Redmine::Hook::ViewListener
	def controller_timelog_edit_before_save(context={ })	
		wktime_helper = Object.new.extend(WktimeHelper)	
		if !context[:time_entry].hours.blank? && !context[:time_entry].activity_id.blank?				
			status = wktime_helper.getTimeEntryStatus(context[:time_entry].spent_on,context[:time_entry].user_id)		
			if !status.blank? && ('a' == status || 's' == status || 'l' == status)					
				 raise "#{l(:label_warning_wktime_time_entry)}"
			end			
		end
	end
	
	def view_layouts_base_html_head(context={})	
		javascript_include_tag('wkstatus', :plugin => 'redmine_wktime') + "\n" +
		stylesheet_link_tag('lockwarning', :plugin => 'redmine_wktime')		
	end
	
	def view_timelog_edit_form_bottom(context={ })		
		showWarningMsg(context[:request],context[:time_entry].user_id, true)
	end
	
	def view_issues_edit_notes_bottom(context={})	
		showWarningMsg(context[:request], User.current.id, false)
	end

	def showWarningMsg(req, user_id, log_time_page)
		wktime_helper = Object.new.extend(WktimeHelper)
		host_with_subdir = wktime_helper.getHostAndDir(req)
		"<div id='divError'>
			<font color='red'></font>		
		</div>
		<input type='hidden' id='getstatus_url' value='#{url_for(:controller => 'wktime', :action => 'getStatus', :host => host_with_subdir, :only_path => true, :user_id => user_id)}'>
		<input type='hidden' id='getissuetracker_url' value='#{url_for(:controller => 'wktime', :action => 'getTracker', :host => host_with_subdir, :only_path => true)}'>
		<input type='hidden' id='log_time_page' value='#{log_time_page}'>
		<input type='hidden' id='label_issue_warn' value='#{l(:label_warning_wktime_issue_tracker)}'>
		<input type='hidden' id='label_time_warn' value='#{l(:label_warning_wktime_time_entry)}'>"
	end
	
	# Added expense report link in redmine core 'projects/show.html' using hook
	def view_projects_show_left(context={})
		if !context[:project].blank?
			wktime_helper = Object.new.extend(WktimeHelper)		
			host_with_subdir = wktime_helper.getHostAndDir(context[:request])	
			project_ids = Setting.plugin_redmine_wktime['wkexpense_projects']		
			if project_ids.blank? || (!project_ids.blank? && (project_ids == [""] || project_ids.include?("#{context[:project].id}"))) && User.current.allowed_to?(:view_time_entries, context[:project])
				"<p style='float:left; padding-left:180px;  margin-top:-45px;'>| #{link_to(l(:label_wkexpense_reports), url_for(:controller => 'wkexpense', :action => 'reportdetail', :project_id => context[:project], :host => host_with_subdir, :only_path => true))}</p>"
			end
		end
	end
	
	def controller_issues_edit_before_save(context={})	
		if !context[:time_entry].blank?
			if !context[:time_entry].hours.blank? && !context[:time_entry].activity_id.blank?
				wktime_helper = Object.new.extend(WktimeHelper)				
				status= wktime_helper.getTimeEntryStatus(context[:time_entry].spent_on,context[:time_entry].user_id)		
				if !status.blank? && ('a' == status || 's' == status || 'l' == status)				
					 raise "#{l(:label_warning_wktime_time_entry)}"					
				end			
			end	
		end
	end
	render_on :view_layouts_base_content, :partial => 'wktime/attendance_widget'	
end




