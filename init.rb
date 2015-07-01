require 'redmine'
require_dependency 'custom_fields_helper'

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
		if @hours > 0			
		  case params[:todo]
		  when 'destroy'
			wktime_helper = Object.new.extend(WktimeHelper)
			issue_id = @issues.map(&:id)
			ret = wktime_helper.getStatus_Project_Issue(issue_id[0],nil)		
			if ret				
				flash.now[:error] = l(:error_project_issue_associate)
				return
			 end
		  when 'nullify'
			TimeEntry.where(['issue_id IN (?)', @issues]).update_all('issue_id = NULL')
		  when 'reassign'
			reassign_to = @project.issues.find_by_id(params[:reassign_to_id])
			if reassign_to.nil?
			  flash.now[:error] = l(:error_issue_not_found_in_project)
			  return
			else
			  TimeEntry.where(['issue_id IN (?)', @issues]).
				update_all("issue_id = #{reassign_to.id}")
			end
		  else
			# display the destroy form if it's a user request
			return unless api_request?
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
  
CustomFieldsHelper.send(:include, WktimeHelperPatch)
ProjectsController.send(:include, ProjectsControllerPatch)
IssuesController.send(:include, IssuesControllerPatch)
TimelogController.send(:include, TimelogControllerPatch)

Redmine::Plugin.register :redmine_wktime do
  name 'Time & Expense'
  author 'Adhi Software Pvt Ltd'
  description 'This plugin is for entering Time & Expense'
  version '1.9'
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
			 'wktime_account_groups' => ['0']
  })  
 
  menu :top_menu, :wkTime, { :controller => 'wktime', :action => 'index' }, :caption => :label_te, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission } 	
  project_module :time_tracking do
	permission :approve_time_entries,  {:wktime => [:update]}, :require => :member	
  end

end


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
						Rails.logger.info "==========Scheduler Started=========="			
						wktime_helper = Object.new.extend(WktimeHelper)
						wktime_helper.sendNonSubmissionMail()
					rescue Exception => e
						Rails.logger.info "Scheduler failed: #{e.message}"
					end
				end
			end
		end
	end
end

class WktimeHook < Redmine::Hook::ViewListener
	def controller_timelog_edit_before_save(context={ })			
		if !context[:time_entry].hours.blank? && !context[:time_entry].activity_id.blank?
			wktime_helper = Object.new.extend(WktimeHelper)				
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
		showWarningMsg(context[:request],context[:time_entry].user_id)
	end
	
	def view_issues_edit_notes_bottom(context={})	
		showWarningMsg(context[:request],User.current.id)
	end

	def showWarningMsg(req,user_id)		
		wktime_helper = Object.new.extend(WktimeHelper)
		host_with_subdir = wktime_helper.getHostAndDir(req)	
		"<div id='divError'><font color='red'>#{l(:label_warning_wktime_time_entry)}</font>	
			<input type='hidden' id='getstatus_url' value='#{url_for(:controller => 'wktime', :action => 'getStatus', :host => host_with_subdir, :only_path => true, :user_id => user_id)}'>	
		</div>"		
	end
	
	# Added expense report link in redmine core 'projects/show.html' using hook
	def view_projects_show_sidebar_bottom(context={})
		if !context[:project].blank?
			wktime_helper = Object.new.extend(WktimeHelper)		
			host_with_subdir = wktime_helper.getHostAndDir(context[:request])	
			project_ids = Setting.plugin_redmine_wktime['wkexpense_projects']		
			if project_ids.blank? || (!project_ids.blank? && (project_ids == [""] || project_ids.include?("#{context[:project].id}"))) && User.current.allowed_to?(:view_time_entries, context[:project])
				"#{link_to(l(:label_wkexpense_reports), url_for(:controller => 'wkexpense', :action => 'reportdetail', :project_id => context[:project], :host => host_with_subdir, :only_path => true))}"
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
end




