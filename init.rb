require 'redmine'
require_dependency 'custom_fields_helper'

module WktimeHelperPatch
	def self.included(base)
		CustomFieldsHelper::CUSTOM_FIELDS_TABS << {:name => 'WktimeCustomField', :partial => 'custom_fields/index', :label => :label_wk_time}
	end	
end

CustomFieldsHelper.send(:include, WktimeHelperPatch)

Redmine::Plugin.register :redmine_wktime do
  name 'Time & Expense'
  author 'Adhi Software Pvt Ltd'
  description 'This plugin is for entering Time & Expense'
  version '1.7'
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
			 'wktime_page_width' => '250',
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
			 'wktime_allow_filter_issue' => '0'
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
			status= wktime_helper.getTimeEntryStatus(context[:time_entry].spent_on,context[:time_entry].user_id)		
			if !status.blank? && ('a' == status || 's' == status)					
				 raise "#{l(:label_warning_wktime_time_entry)}"
			end			
		end	
	end
	
	def view_layouts_base_html_head(context={})	
		javascript_include_tag('wkstatus', :plugin => 'redmine_wktime') + "\n" +
		stylesheet_link_tag('lockwarning', :plugin => 'redmine_wktime')		
	end
	
	def view_timelog_edit_form_bottom(context={ })		
		showWarningMsg(context[:request])
	end
	
	def view_issues_edit_notes_bottom(context={})	
		showWarningMsg(context[:request])	
	end

	def showWarningMsg(req)		
		wktime_helper = Object.new.extend(WktimeHelper)		
		host_with_subdir = wktime_helper.getHostAndDir(req)				
		"<div id='divError'><font color='red'>#{l(:label_warning_wktime_time_entry)}</font>	
			<input type='hidden' id='getstatus_url' value='#{url_for(:controller => 'wktime', :action => 'getStatus',:host => host_with_subdir, :only_path=>true)}'>
		</div>"		
	end
	
	# Added expense report link in redmine core 'projects/show.html' using hook
	def view_projects_show_sidebar_bottom(context={})
		if !context[:project].blank?
			wktime_helper = Object.new.extend(WktimeHelper)		
			host_with_subdir = wktime_helper.getHostAndDir(context[:request])	
			project_ids = Setting.plugin_redmine_wktime['wkexpense_projects']		
			if project_ids.blank? || (!project_ids.blank? && (project_ids == [""] || project_ids.include?("#{context[:project].id}"))) && User.current.allowed_to?(:view_time_entries, context[:project])
				"#{link_to(l(:label_wkexpense_reports), url_for(:controller => 'wkexpense', :action => 'reportdetail', :project_id => context[:project], :host => host_with_subdir, :only_path=>true))}"
			end
		end
	end
end




