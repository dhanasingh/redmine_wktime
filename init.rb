require 'redmine'
require_dependency 'custom_fields_helper'
require_dependency '../lib/redmine/menu_manager'
require 'fileutils'
require 'timelogcontroller_patch'
require 'time_report_patch'
require_dependency 'queries_helper_patch'
require 'userscontroller_patch'
require_dependency 'ftte/ftte_hook'
require 'wkapplication_helper_patch'

User.class_eval do
	has_one :wk_user, :dependent => :destroy, :class_name => 'WkUser'
	has_many :shift_schdules, :dependent => :destroy, :class_name => 'WkShiftSchedule'
	def erpmineuser
		self.wk_user ||= WkUser.new(:user => self)
	end
end

Issue.class_eval do
	has_one :wk_issue, :dependent => :destroy, :class_name => 'WkIssue'
	has_many :assignees, :dependent => :destroy, :class_name => 'WkIssueAssignee'
	has_many :expense_entries, :dependent => :destroy, :class_name => 'WkExpenseEntry'
	accepts_nested_attributes_for :assignees
	accepts_nested_attributes_for :wk_issue
	def erpmineissues
		self.wk_issue ||= WkIssue.new(:issue => self, :project => self.project)
	end	
end

Project.class_eval do
	has_many :account_projects, :dependent => :destroy, :class_name => 'WkAccountProject'
	#has_many :parents, through: :account_projects
	has_one :wk_project, :dependent => :destroy, :class_name => 'WkProject'
	def erpmineproject
			self.wk_project ||= WkProject.new(:project => self)
	end	
end


TimeEntry.class_eval do
  has_one :spent_for, as: :spent, class_name: 'WkSpentFor', :dependent => :destroy
  has_one :invoice_item, through: :spent_for
  
  accepts_nested_attributes_for :spent_for
end

# redmine only differs between project_menu and application_menu! but we want to display the
# time_tracker submenu only if the plugin specific controllers are called
module Redmine::MenuManager::MenuHelper
  def display_main_menu?(project)
    Redmine::MenuManager.items(menu_name(project)).children.present?
  end

  def render_main_menu(project)
    if menu_name = controller.current_menu(project)
        render_menu(menu_name(project), project) 
    end
  end

  private

  def menu_name(project)
    if project && !project.new_record?
      :project_menu
    else
	  controllerArr = ["wktime", "wkexpense", "wkattendance", "wkreport", "wkpayroll",  "wkinvoice", "wkcrmaccount", "wkcontract", "wkaccountproject", "wktax", "wkgltransaction", "wkledger", "wklead", "wkopportunity", "wkcrmactivity", "wkcrmcontact", "wkcrmenumeration", "wkpayment", "wkexchangerate","wkpurchase","wkrfq","wkquote","wkpurchaseorder","wksupplierinvoice","wksupplierpayment","wksupplieraccount","wksuppliercontact", "wklocation", "wkproduct", "wkbrand", "wkattributegroup" , "wkproductitem", "wkshipment", "wkunitofmeasurement", "wkasset", "wkassetdepreciation", "wkgrouppermission", "wkscheduling", "wkshift", "wkpublicholiday", "wkdashboard", "wksurvey"]
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
			def create
				@issue_custom_fields = IssueCustomField.sorted.to_a
				@trackers = Tracker.sorted.to_a
				@project = Project.new
				@project.safe_attributes = params[:project]
			
				if @project.save
					# ============= ERPmine_patch Redmine 4.0 =====================
					 @project.erpmineproject.safe_attributes = params[:erpmineproject]
					 @project.erpmineproject.save
					# =============================
				  unless User.current.admin?
					@project.add_default_member(User.current)
				  end
				  respond_to do |format|
					format.html {
					  flash[:notice] = l(:notice_successful_create)
					  if params[:continue]
						attrs = {:parent_id => @project.parent_id}.reject {|k,v| v.nil?}
						redirect_to new_project_path(attrs)
					  else
						redirect_to settings_project_path(@project)
					  end
					}
					format.api  { render :action => 'show', :status => :created, :location => url_for(:controller => 'projects', :action => 'show', :id => @project.id) }
				  end
				else
				  respond_to do |format|
					format.html { render :action => 'new' }
					format.api  { render_validation_errors(@project) }
				  end
				end
			end

			def update
				@project.safe_attributes = params[:project]
				if @project.save
					# ============= ERPmine_patch Redmine 4.0 =====================
					 @project.erpmineproject.safe_attributes = params[:erpmineproject]
					 @project.erpmineproject.save
					# =============================
					respond_to do |format|
						format.html {
							flash[:notice] = l(:notice_successful_update)
							redirect_to settings_project_path(@project, params[:tab])
						}
						format.api  { render_api_ok }
					end
				else
					respond_to do |format|
						format.html {
							settings
							render :action => 'settings'
						}
						format.api  { render_validation_errors(@project) }
					end
				end
			end
			
		  def destroy	
			 @project_to_destroy = @project
				if api_request? || params[:confirm]
				# ============= ERPmine_patch Redmine 4.0 =====================
					wktime_helper = Object.new.extend(WktimeHelper)
					ret = wktime_helper.getStatus_Project_Issue(nil,@project_to_destroy.id)			
					if ret
						#render_403
						#return false
						flash.now[:error] = l(:error_project_issue_associate)
						return
					else
						WkExpenseEntry.where(['project_id = ?', @project_to_destroy.id]).delete_all
				# =============================
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
		raise Unauthorized unless @issues.all?(&:deletable?)

		# all issues and their descendants are about to be deleted
		issues_and_descendants_ids = Issue.self_and_descendants(@issues).pluck(:id)
		time_entries = TimeEntry.where(:issue_id => issues_and_descendants_ids)
		@hours = time_entries.sum(:hours).to_f
		
		# ============= ERPmine_patch Redmine 4.0 =====================
		expense_entries = WkExpenseEntry.where(:issue_id => issues_and_descendants_ids)
		@amount = expense_entries.sum(:amount).to_f
		# =============================================================

		if @hours > 0 || @amount > 0 # added check for expense entry
			
		  # ============= ERPmine_patch Redmine 4.0 =====================
		  # Check for the submitted or approve time and expense entries
		  # show error message when there is a submitted time or expense entry
		  # if part wrote by us and else part has expense destroy wrote by us
		  
		  wktime_helper = Object.new.extend(WktimeHelper)
		  issue_id = @issues.map(&:id)
		  ret = wktime_helper.getStatus_Project_Issue(issue_id[0],nil)
		  if ret				
			  flash.now[:error] = l(:error_project_issue_associate)
			  return
		  else
			  case params[:todo]
			  when 'destroy'
				# nothing to do
			  when 'nullify'
				if Setting.timelog_required_fields.include?('issue_id')
				  flash.now[:error] = l(:field_issue) + " " + ::I18n.t('activerecord.errors.messages.blank')
				  return
				else
					time_entries.update_all(:issue_id => nil)
					
					# ============= ERPmine_patch Redmine 4.0 ===========
					expense_entries.update_all(:issue_id => nil)
					# ==============================================
				end
			  when 'reassign'
				reassign_to = @project && @project.issues.find_by_id(params[:reassign_to_id])
				if reassign_to.nil?
				  flash.now[:error] = l(:error_issue_not_found_in_project)
				  return
				elsif issues_and_descendants_ids.include?(reassign_to.id)
				  flash.now[:error] = l(:error_cannot_reassign_time_entries_to_an_issue_about_to_be_deleted)
				  return
				else
				  time_entries.update_all(:issue_id => reassign_to.id, :project_id => reassign_to.project_id)
				  
				  # ============= ERPmine_patch Redmine 4.0 ===========
					expense_entries.update_all(:issue_id => reassign_to.id, :project_id => reassign_to.project_id)
				  # ==============================================
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

  
CustomFieldsHelper.send(:include, WktimeHelperPatch)
ProjectsController.send(:include, ProjectsControllerPatch)
IssuesController.send(:include, IssuesControllerPatch)
TimelogController.send(:include, TimelogControllerPatch)
UsersController.send(:include, UsersControllerPatch)

# Patches for Supervisor

module FttePatch
  module UserPatch
    def self.included(base)
      #base.send(:include)

      base.class_eval do
        #unloadable
		belongs_to :supervisor, :class_name => 'User', :foreign_key => 'parent_id'
		include FTTE::NestedSet::UserNestedSet
        safe_attributes 'parent_id', 'lft', 'rgt'
      end	  
    end
  end
  
  module UserAllowedToPatch
	def self.included(base)
      #base.send(:include)

      base.class_eval do
				def allowed_to?(action, context, options={}, &block)
					# ======= ERPmine_patch Redmine 4.0 ==========
					wktime_helper = Object.new.extend(WktimeHelper)
					valid_ERP_perm = wktime_helper.validateERPPermission('A_TE_PRVLG')
					isSupervisor = wktime_helper.isSupervisor
					# =============================
					if context && context.is_a?(Project)
						# ======= ERPmine_patch Redmine 4.0 for allow supervisor and TEadmin to view time_entry ==========
						if ((valid_ERP_perm || isSupervisor) && action.to_s == 'view_time_entries') && wktime_helper.overrideSpentTime
						return true
						end
						
						if (action.to_s == 'view_time_entries') && wktime_helper.overrideSpentTime
						(context.allows_to?(:log_time) || context.allows_to?(:edit_time_entries) || context.allows_to?(:edit_own_time_entries))
						end
						# =============================
				
						return false unless context.allows_to?(action)
						# Admin users are authorized for anything else
						return true if admin?
	
						roles = roles_for_project(context)
						return false unless roles
						roles.any? {|role|
						(context.is_public? || role.member?) &&
						role.allowed_to?(action) &&
						(block_given? ? yield(role, self) : true)
						}
					elsif context && context.is_a?(Array)
						if context.empty?
						false
						else
						# Authorize if user is authorized on every element of the array
						context.map {|project| allowed_to?(action, project, options, &block)}.reduce(:&)
						end
					elsif context
						raise ArgumentError.new("#allowed_to? context argument must be a Project, an Array of projects or nil")
					elsif options[:global]			  
						# Admin users are always authorized
						return true if admin?
						
						# ======= ERPmine_patch Redmine 4.0 ==========
						if ((valid_ERP_perm || isSupervisor) && action.to_s == 'view_time_entries') && wktime_helper.overrideSpentTime
						return true
						end
						# =============================
						# authorize if user has at least one role that has this permission
						roles = self.roles.to_a | [builtin_role]
						roles.any? {|role|
						# ======= ERPmine_patch Redmine 4.0 ==========
						if (action.to_s == 'view_time_entries') && wktime_helper.overrideSpentTime
							(role.allowed_to?(:log_time) || role.allowed_to?(:edit_time_entries) || role.allowed_to?(:edit_own_time_entries))
						else
						# =============================
							role.allowed_to?(action) &&
							(block_given? ? yield(role, self) : true)
						end
						}
					else
						false
					end
				end
      end	  
    end
  end
 
  module TimeEntryPatch
	def self.included(base)
		#base.send(:include)
		
		base.class_eval do
			def editable_by?(usr)
				# === ERPmine_patch Redmine 4.0 for supervisor edit =====
				wktime_helper = Object.new.extend(WktimeHelper)
				if ((!user.blank? && wktime_helper.isSupervisorForUser(user.id)) && wktime_helper.canSupervisorEdit)
					true
				else
				# =============================
					visible?(usr) && (
					  (usr == user && usr.allowed_to?(:edit_own_time_entries, project)) || usr.allowed_to?(:edit_time_entries, project)
					)				
				end
			end
		end
	end
  end
   
  module ApplicationControllerPatch
	def self.included(base)
		# base.send(:include)
		
		base.class_eval do
		  def authorize(ctrl = params[:controller], action = params[:action], global = false)
				allowed = User.current.allowed_to?({:controller => ctrl, :action => action}, @project || @projects, :global => global)
				if allowed
					true
				else
				# ============= ERPmine_patch Redmine 4.0 =====================
							wktime_helper = Object.new.extend(WktimeHelper)
							# isSupervisor = wktime_helper.isSupervisor
				# =============================
					if @project && @project.archived?
						@archived_project = @project
						render_403 :message => :notice_not_authorized_archived_project
				# ============= ERPmine_patch Redmine 4.0 =====================
					elsif ((action == 'edit' || action == 'update' || action == 'destroy') && ctrl == 'timelog' && (wktime_helper.isSupervisor && wktime_helper.canSupervisorEdit)) && wktime_helper.overrideSpentTime
						true
					elsif ((action == 'index' || action == 'report')  && ctrl == 'timelog') && wktime_helper.overrideSpentTime
						#Object.new.extend(WktimeHelper).isAccountUser || isSupervisor
						return true
				# =============================
					elsif @project && !@project.allows_to?(:controller => ctrl, :action => action)
						# Project module is disabled
						render_403
					else
						deny_access
					end
				end
			end
		end
	end
  end
  
  # module ProjectPatch
	# def self.included(base)
		# #base.send(:include)
		
		# base.class_eval do
		  # # Returns a SQL conditions string used to find all projects for which +user+ has the given +permission+
		  # #
		  # # Valid options:
		  # # * :skip_pre_condition => true       don't check that the module is enabled (eg. when the condition is already set elsewhere in the query)
		  # # * :project => project               limit the condition to project
		  # # * :with_subprojects => true         limit the condition to project and its subprojects
		  # # * :member => true                   limit the condition to the user projects
		  # def self.allowed_to_condition(user, permission, options={})
			# perm = Redmine::AccessControl.permission(permission)
			# base_statement = (perm && perm.read? ? "#{Project.table_name}.status <> #{Project::STATUS_ARCHIVED}" : "#{Project.table_name}.status = #{Project::STATUS_ACTIVE}")
			# if !options[:skip_pre_condition] && perm && perm.project_module
			  # # If the permission belongs to a project module, make sure the module is enabled
			  # base_statement << " AND EXISTS (SELECT 1 AS one FROM #{EnabledModule.table_name} em WHERE em.project_id = #{Project.table_name}.id AND em.name='#{perm.project_module}')"
			# end
			# if project = options[:project]
			  # project_statement = project.project_condition(options[:with_subprojects])
			  # base_statement = "(#{project_statement}) AND (#{base_statement})"
			# end
			
			# wktime_helper = Object.new.extend(WktimeHelper)
			# if user.admin?
			  # base_statement
			# # Path code for overide redmine spentime 
			# elsif wktime_helper.isSupervisorApproval && wktime_helper.isSupervisor && !wktime_helper.isAccountUser && wktime_helper.overrideSpentTime
				# base_statement + self.getSupervisorCondStr(user)
			# else
			  # statement_by_role = {}
			  # unless options[:member]
				# role = user.builtin_role
				# if role.allowed_to?(permission)
				  # s = "#{Project.table_name}.is_public = #{connection.quoted_true}"
				  # if user.id
					# group = role.anonymous? ? Group.anonymous : Group.non_member
					# principal_ids = [user.id, group.id].compact
					# s = "(#{s} AND #{Project.table_name}.id NOT IN (SELECT project_id FROM #{Member.table_name} WHERE user_id IN (#{principal_ids.join(',')})))"
				  # end
				  # statement_by_role[role] = s
				# end
			  # end
			  # user.project_ids_by_role.each do |role, project_ids|
				# if role.allowed_to?(permission) && project_ids.any?
				  # statement_by_role[role] = "#{Project.table_name}.id IN (#{project_ids.join(',')})"
				# end
			  # end
			  # if statement_by_role.empty?
				# "1=0"
			  # else
				# if block_given?
				  # statement_by_role.each do |role, statement|
					# if s = yield(role, user)
					  # statement_by_role[role] = "(#{statement} AND (#{s}))"
					# end
				  # end
				# end
				# "((#{base_statement}) AND (#{statement_by_role.values.join(' OR ')}))"
			  # end
			# end
		  # end
		  
		  # def self.getSupervisorCondStr(user)
			# wktime_helper = Object.new.extend(WktimeHelper)
			# cond = ""
			# project_ids = wktime_helper.getUsersProjects(user.id, true).collect{|proj| proj.id }.map(&:inspect).join(', ')
			# unless project_ids.blank?
				# cond = " AND #{Project.table_name}.id IN (#{project_ids})"
			# end
			# cond
		  # end
		# end
	# end
  # end
 
 module TimeEntryQueryPatch
	def self.included(base)
      # base.send(:include)

    base.class_eval do
        unloadable
			def base_scope
				TimeEntry.visible.
					joins(:project, :user).
					includes(:activity).
					references(:activity).
					left_join_issue.
					where(getSupervisorCondStr)
			end
		
			#========= ERPmine_patch Redmine 4.0 for get supervision condition string ======
			def getSupervisorCondStr
				orgCondStatement = statement
				condStatement = orgCondStatement
				
				wktime_helper = Object.new.extend(WktimeHelper)
				if wktime_helper.overrideSpentTime
					valid_ERP_perm = wktime_helper.validateERPPermission('A_TE_PRVLG')
					isSupervisor = wktime_helper.isSupervisor
					projectIdArr = wktime_helper.getManageProject()
					isManager = projectIdArr.blank? ? false : true
					
					if isSupervisor && !valid_ERP_perm && !User.current.admin?
						userIdArr = Array.new
						user_cond = ""
						rptUsers = wktime_helper.getReportUsers(User.current.id)
						userIdArr = rptUsers.collect(&:id) if !rptUsers.blank?
						userIdArr = userIdArr << User.current.id.to_s
						userIds = "#{userIdArr.join(',')}"
						user_cond = "#{TimeEntry.table_name}.user_id IN (#{userIds})"
						
						if condStatement.blank?
							condStatement = "(#{user_cond})" if !user_cond.blank?
						else				
							if filters["user_id"].blank?			
								condStatement = user_cond.blank? ? condStatement : condStatement + " AND (#{user_cond})"
							else						
								user_id = filters["user_id"][:values]
								userIdStrArr = userIdArr.collect{|i| i.to_s}
								filterUserIds = userIdStrArr & filters["user_id"][:values]
								
								if !filterUserIds.blank?
									if user_id.is_a?(Array) && user_id.include?("me")
										filterUserIds << (User.current.id).to_s
									end
									filters["user_id"][:values] = filterUserIds #overriding user filters to get query condition for supervisor
									condStatement = statement
									filters["user_id"][:values] = user_id #Setting the filter values to retain the filter on page						
								else
									if user_id.is_a?(Array) && user_id.include?("me")
										filters["user_id"][:values] = [User.current.id.to_s]
										condStatement = statement
										filters["user_id"][:values] = user_id
									else
										condStatement = "1=0"
									end
								end
							end
						end
						if isManager
							mgrCondStatement = ""
							if !orgCondStatement.blank?
								mgrCondStatement = orgCondStatement + " AND "
							end
							mgrCondStatement = mgrCondStatement + "(#{TimeEntry.table_name}.project_id in (" + projectIdArr.collect{|i| i.to_s}.join(',') + "))"
							condStatement = condStatement.blank? ? condStatement : "(" + condStatement + ") OR (" + mgrCondStatement + ")"
						end
					else
						#if (!Setting.plugin_redmine_wktime['ftte_view_only_own_spent_time'].blank? && 
						#Setting.plugin_redmine_wktime['ftte_view_only_own_spent_time'].to_i == 1) && 
						if !valid_ERP_perm && !User.current.admin? && !isManager
							cond = " (#{TimeEntry.table_name}.user_id = " + User.current.id.to_s + ")"
							condStatement = condStatement.blank? ? cond : condStatement + " AND #{cond}"
						elsif isManager && !valid_ERP_perm && !User.current.admin?
							user_id = filters["user_id"][:values] if !filters["user_id"].blank?
							if !user_id.blank? && user_id.is_a?(Array) && (user_id.include?("me") || user_id.include?(User.current.id.to_s))
								condStatement = condStatement
							else
								condStatement = condStatement.blank? ? condStatement : "(" + condStatement + ") AND (#{TimeEntry.table_name}.project_id in (" + projectIdArr.collect{|i| i.to_s}.join(',') + "))"
							end
						end
					end
				end
				condStatement
			end
			# =============================
			end
		end
  end
end

Rails.configuration.to_prepare do
	# Add module to User class
	User.send(:include, FttePatch::UserPatch)
	# Project.send(:include, FttePatch::ProjectPatch)
	TimeEntry.send(:include, FttePatch::TimeEntryPatch)
	
	#if ActiveRecord::Base.connection.table_exists? "#{Setting.table_name}"
	#	if (!Setting.plugin_redmine_wktime['ftte_override_spent_time_report'].blank? && Setting.plugin_redmine_wktime['ftte_override_spent_time_report'].to_i == 1)
		#end
	#end
	User.send(:include, FttePatch::UserAllowedToPatch)
	ApplicationController.send(:include, FttePatch::ApplicationControllerPatch)
	TimeEntryQuery.send(:include, FttePatch::TimeEntryQueryPatch)

end

Redmine::Plugin.register :redmine_wktime do
  name 'ERPmine'
  author 'Adhi Software Pvt Ltd'
  description 'ERPmine is an ERP for Service Industries. It has the following modules: Time & Expense, Attendance, Payroll, CRM, Billing, Accounting, Purchasing, Inventory, Asset , Reports, Dashboards and Survey'
  version '3.7.1'
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
			 'wktime_enable_purchase_module' => '0',
			 'wktime_pur_group' => '0',
			 'wktime_pur_admin' => '0',
			 'wktime_enable_inventory_module' => '0',
			 'wktime_inventory_admin' => '0',
			 'wktime_depreciation_type' => '0',
			 'wktime_depreciation_ledger' => '0',
			 'auto_apply_depreciation' => '0',
			 'wktime_depreciation_frequency' => '0',
			 'wktime_enable_shift scheduling_module' => '0',
			 'wk_schedule_on_weekend' => '0',
			 'wk_schedule_weekend' => '0',
			 'wk_scheduling_frequency' => '0',
			 'wk_day_off_per_frequency' => '0',
			 'wk_user_schedule_preference' => '0',
			 'wk_auto_shift_scheduling' => '0',
			 'ftte_edit_time_log' => '0',
			 'ftte_override_spent_time_report' => '0',
			 'ftte_supervisor_based_approved' => '0',
			 'ftte_view_only_own_spent_time' => '0',
			 'wktime_enable_dashboards_module' => '0',
			 'wktime_enable_survey_module' => '0'
  })  

	menu :top_menu, :wkdashboard, { :controller => 'wkdashboard', :action => 'index' }, :caption => :label_erpmine,
	 :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && ActiveModel::Type::Boolean.new.cast(Object.new.extend(WktimeHelper).show_plugin_name) } 
  	
  	project_module :time_tracking do
		permission :approve_time_entries,  {:wktime => [:update]}, :require => :member	
	end

	project_module :Accounts do
		permission :view_accounts, {:wkaccountproject => [:index]}, :public => true
	end
	
	menu :project_menu, :wkaccountproject, { controller: :wkaccountproject, action: :index },
	  caption: :label_accounts, param: :project_id, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showCRMModule }
  
	project_module :Survey do
		permission :view_survey, {:wksurvey => [:index]}, :public => true
	end

	menu :project_menu, :wksurvey, { :controller => 'wksurvey', :action => 'index' }, :caption => :label_survey, param: :project_id, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showSurvey }

  Redmine::MenuManager.map :wktime_menu do |menu|
	  menu.push :wkdashboard, { :controller => 'wkdashboard', :action => 'index' }, :caption => :label_dashboards, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WkdashboardHelper).showDashboard && Object.new.extend(WktimeHelper).hasSettingPerm}
	  menu.push :wktime, { :controller => 'wktime', :action => 'index' }, :caption => :label_te, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && (Object.new.extend(WktimeHelper).showTime || Object.new.extend(WktimeHelper).showExpense)}
	  menu.push :wkattendance, { :controller => 'wkattendance', :action => 'index' }, :caption => :label_hr, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && (Object.new.extend(WktimeHelper).showAttendance || Object.new.extend(WktimeHelper).showPayroll || Object.new.extend(WktimeHelper).showShiftScheduling || Object.new.extend(WktimeHelper).showSurvey)}
	  menu.push :wklead, { :controller => 'wklead', :action => 'index' }, :caption => :label_crm, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showCRMModule }
	  menu.push :wkinvoice, { :controller => 'wkinvoice', :action => 'index' }, :caption => :label_wk_billing, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showBilling && Object.new.extend(WktimeHelper).validateERPPermission("M_BILL")}
	  menu.push :wkgltransaction, { :controller => 'wkgltransaction', :action => 'index' }, :caption => :label_accounting, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showAccounting }
	  menu.push :wkrfq, { :controller => 'wkrfq', :action => 'index' }, :caption => :label_purchasing, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showPurchase }
	  menu.push :wkproduct, { :controller => 'wkproduct', :action => 'index' }, :caption => :label_inventory, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showInventory }
      menu.push :wksurvey, { :controller => 'wksurvey', :action => 'index' }, :caption => :label_survey, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showSurvey }
	  menu.push :wkreport, { :controller => 'wkreport', :action => 'index' }, :caption => :label_report_plural, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showReports && Object.new.extend(WktimeHelper).validateERPPermission("V_REPORT")}	
	  menu.push :wkcrmenumeration, { :controller => 'wkcrmenumeration', :action => 'index' }, :caption => :label_settings, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).hasSettingPerm } 
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
					wkattn_helper.populateWkUserLeaves(Date.today)
					Rails.logger.info "==========Attendance job - Completed=========="
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
					Rails.logger.error "Import failed: #{e.message}"
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
						errorMsg = wkpayroll_helper.generateSalaries(nil,currentMonthStart,"true")
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
		
		if (!Setting.plugin_redmine_wktime['auto_apply_depreciation'].blank? && Setting.plugin_redmine_wktime['auto_apply_depreciation'].to_i == 1)
			require 'rufus/scheduler'
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
			require 'rufus/scheduler'
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
	
	# def view_layouts_base_html_head(context={})	
		# wktime_helper = Object.new.extend(WktimeHelper)
		# host_with_subdir = wktime_helper.getHostAndDir(context[:request])
		# "<input type='hidden' id='getspenttype_url' value='#{url_for(:controller => 'wklogmaterial', :action => 'loadSpentType', :host => host_with_subdir, :only_path => true)}'>"
		
	
		# javascript_include_tag('wkstatus', :plugin => 'redmine_wktime') + "\n" +
		# javascript_include_tag('index', :plugin => 'redmine_wktime') + "\n" +
		# stylesheet_link_tag('lockwarning', :plugin => 'redmine_wktime')		
		
		
	# end
	
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
	render_on :view_timelog_edit_form_bottom, :partial => 'wklogmaterial/log_material'
	render_on :view_users_form, :partial => 'wkuser/wk_user', locals: { myaccount: false }
	render_on :view_users_form_preferences, :partial => 'wkuser/wk_user_address', locals: { myaccount: false }
	render_on :view_my_account, :partial => 'wkuser/wk_user', locals: { myaccount: true }
	render_on :view_my_account_preferences, :partial => 'wkuser/wk_user_address', locals: { myaccount: true }
	render_on :view_issues_form_details_bottom, :partial => 'wkissues/wk_issue_fields'
	
	def controller_issues_edit_before_save(context={})
		saveErpmineIssues(context[:issue], context[:params][:erpmineissues])
		saveErpmineIssueAssignee(context[:issue], context[:issue][:project_id], context[:params][:wk_issue_assignee])
	end
	
	def controller_issues_new_before_save(context={})	
		saveErpmineIssues(context[:issue], context[:params][:erpmineissues])
		saveErpmineIssueAssignee(context[:issue], context[:issue][:project_id], context[:params][:wk_issue_assignee])
	end
	
	def saveErpmineIssues(issueObj, issueParm)
		issueObj.erpmineissues.safe_attributes = issueParm
	end
	
	def saveErpmineIssueAssignee(issueObj, projectId, userIdArr)		
		 assigneeAttributes = Array.new
		# userIdArr.each do |userId|
			# assigneeAttributes << {user_id: userId.to_i, project_id: projectId}			
		# end
		# issueObj.assignees_attributes = assigneeAttributes		
		WkIssueAssignee.where(:issue_id => issueObj.id).where.not(:user_id => userIdArr).delete_all()
		unless userIdArr.blank?
			userIdArr.collect{ |id| 
				iscount = WkIssueAssignee.where("issue_id = ? and user_id = ? ", issueObj.id, id).count
				unless iscount > 0
					assigneeAttributes << {user_id: id.to_i, project_id: projectId}
				end						
			}
		end
		issueObj.assignees_attributes = assigneeAttributes	
	end
	
	render_on :view_issues_show_description_bottom, :partial => 'wkissues/show_wk_issues'
	render_on :view_layouts_base_html_head, :partial => 'wkbase/base_header'
	render_on :view_projects_form, :partial => 'wkproject/project_settings'
		
end