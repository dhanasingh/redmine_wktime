# Load Patch files
begin
  Dir[File.join(File.dirname(__FILE__), 'lib', '**', '*.rb')].each do |file|
    path = File.dirname(file).split('/').last
		if ['load_patch', 'send_patch'].include?(path)
			require_dependency file
		end

    if path == 'send_patch'
			folder = path.camelize
      patch_class = File.basename(file, '.rb').camelize
      target_class = patch_class.sub('Patch', '').constantize
      patch_module = "#{folder}::#{patch_class}".constantize
      target_class.send(:include, patch_module)
    end
  end
rescue => e
  puts e.message
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
	  controllerArr = [
			"wktime", "wkexpense", "wkattendance", "wkreport", "wkpayroll",  "wkinvoice", "wkcrmaccount", "wkcontract", "wkaccountproject", "wktax", "wkgltransaction",
			"wkledger", "wklead", "wkopportunity", "wkcrmactivity", "wkcrmcontact", "wkcrmenumeration", "wkpayment", "wkexchangerate","wkrfq","wkquote",
			"wkpurchaseorder","wksupplierinvoice","wksupplierpayment","wksupplieraccount","wksuppliercontact", "wklocation", "wkproduct", "wkbrand", "wkattributegroup",
			"wkproductitem", "wkshipment", "wkunitofmeasurement", "wkasset", "wkassetdepreciation", "wkgrouppermission", "wkscheduling", "wkshift", "wkpublicholiday",
			"wkdashboard", "wksurvey", "wkleaverequest", "wkdocument", "wknotification", "wkskill", "wkreferrals", "wkdelivery", "wksalesquote", "wkcrmdashboard", "wkuser"
		]
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


Rails.configuration.to_prepare do
	# Add module to User class
	TimeEntry.send(:include, LoadPatch::EditablebyTimeEntryPatch)
	User.send(:include, LoadPatch::AllowedtoUserPatch)
	ApplicationController.send(:include, LoadPatch::AuthAppControllerPatch)
	if ActiveRecord::Base.connection.table_exists?("#{User.table_name}") &&
		ActiveRecord::Base.connection.column_exists?("#{User.table_name}", :parent_id)
		TimeEntryQuery.send(:include, LoadPatch::ScopeTimeEntryQueryPatch)
	end
end

# Models patches
ApplicationRecord.class_eval do
	def get_comp_con(table, cond = 'AND')
		cond = Redmine::Hook.call_hook(:get_comp_condition, table: table, cond: cond) || []
		cond[0] || ""
	end

	def self.get_comp_con(table, cond = 'AND')
		cond = Redmine::Hook.call_hook(:get_comp_condition, table: table, cond: cond) || []
		cond[0] || ""
	end
end

TimeEntryQuery.class_eval do
  self.available_columns += [
    QueryColumn.new(:weekly_timesheet, caption: -> { l(:label_weekly) +" "+ l(:label_wk_timesheet)})
  ]
end

TimeEntry.class_eval do

	has_one :spent_for, as: :spent, class_name: 'WkSpentFor', :dependent => :destroy
	has_one :invoice_item, through: :spent_for
	has_one :wkstatus, as: :status_for, class_name: "WkStatus", dependent: :destroy
	has_many :attachments, -> {where(container_type: "TimeEntry")}, class_name: "Attachment", foreign_key: "container_id", dependent: :destroy
	accepts_nested_attributes_for :spent_for, :attachments

	def attachments_editable?(user=User.current)
		true
	end

	def attachments_deletable?(user=User.current)
		true
	end

	def weekly_timesheet
		status = Wktime.where(begin_date: (self.spent_on - 6.days)..self.spent_on, user_id: self.user_id)&.first&.status

		if status == 'n'
			return l(:label_new)
		elsif status == 'a'
			return l(:wk_status_approved)
		elsif status == 's'
			return l(:wk_status_submitted)
		elsif status == 'r'
			return l(:default_issue_status_rejected)
		else
			return ""
		end
	end
end

User.class_eval do
	include LoadPatch::UserNestedSet
	has_one :wk_user, :dependent => :destroy, :class_name => 'WkUser'
	has_many :shift_schdules, :dependent => :destroy, :class_name => 'WkShiftSchedule'
	belongs_to :supervisor, :class_name => 'User', :foreign_key => 'parent_id'
	has_one :address, through: :wk_user

	safe_attributes 'parent_id', 'lft', 'rgt'
	acts_as_attachable :view_permission => :view_files,
										:edit_permission => :manage_files,
										:delete_permission => :manage_files

	def erpmineuser
		self.wk_user ||= WkUser.new(:user => self)
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

Redmine::Plugin.register :redmine_wktime do
  name 'ERPmine'
  author 'Adhi Software Pvt Ltd'
  description 'ERPmine is an ERP for Service Industries. It has the following modules: Time & Expense, Attendance, Payroll, CRM, Billing, Accounting, Purchasing, Inventory, Asset , Reports, Dashboards and Survey'
  version '4.9.2'
  url 'https://www.redmine.org/plugins/wk-time'
  author_url 'http://www.adhisoftware.co.in/'

  settings(:partial => 'settings',
           :default => {
			 'wktime_closed_issue_ind' => '0',
			 'wktime_page_width' => '210',
			 'wktime_page_height' => '297',
			 'wktime_margin_top' => '20',
			 'wktime_margin_bottom' => '20',
			 'wktime_margin_left' => '10',
			 'wktime_margin_right' => '10',
			 'wktime_line_space' => '4',
			 'wktime_work_time_header' => '0',
			 'wktime_allow_blank_issue' => '0',
			 'wktime_enter_comment_in_row' => '1',
 			 'wktime_use_detail_popup' => '0',
 			 'wktime_use_approval_system' => '0',
 			 'wktime_uuto_approve' => '0',
			 'wktime_submission_ack' => 'I Acknowledge that the hours entered are accurate to the best of my knowledge',
			 'wktime_enter_cf_in_row1' => '0',
			 'wktime_enter_cf_in_row2' => '0',
			 'wktime_own_approval' => '0',
			 'wktime_previous_template_week' => '1',
			 'wkexpense_issues_filter_tracker' => ['0'],
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
			 'wktime_max_hour_week' => '0',
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
		permission :view_accounts, {:wkaccountproject => [:index]}, :public => false
	end

	menu :project_menu, :wkaccountproject, { controller: :wkaccountproject, action: :index },
	  caption: :label_accounts, param: :project_id, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showCRMModule }

	project_module :Survey do
		permission :view_survey, {:wksurvey => [:index]}, :public => false
	end

	menu :project_menu, :wksurvey, { :controller => 'wksurvey', :action => 'index' }, :caption => :label_survey, param: :project_id, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showSurvey }

	project_module :Skills do
		permission :view_skill, {:wkskill => [:index]}, :public => false
	end

	menu :project_menu, :wkskill, {:controller => 'wkskill', :action => 'index' }, :caption => :label_wk_skill, :param => :project_id, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showSkill }

  Redmine::MenuManager.map :wktime_menu do |menu|
	  menu.push :wkdashboard, { :controller => 'wkdashboard', :action => 'index' }, :caption => :label_dashboards, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WkdashboardHelper).showDashboard }
	  menu.push :wktime, { :controller => 'wktime', :action => 'index' }, :caption => :label_te, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && (Object.new.extend(WktimeHelper).showTime || Object.new.extend(WktimeHelper).showExpense)}
	  menu.push :wkattendance, { :controller => 'wkuser', :action => 'index' }, :caption => :label_hr, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && (Object.new.extend(WktimeHelper).showAttendance || Object.new.extend(WktimeHelper).showPayroll || Object.new.extend(WktimeHelper).showShiftScheduling || Object.new.extend(WktimeHelper).showSurvey)}
	  menu.push :wkcrmdashboard, { :controller => 'wkcrmdashboard', :action => 'index' }, :caption => :label_crm, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showCRMModule }
		Redmine::Hook.call_hook(:wktime_menu_hook, menu: menu) # Call hook to add external menus
	  menu.push :wkinvoice, { :controller => 'wkinvoice', :action => 'index' }, :caption => :label_wk_billing, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showBilling && Object.new.extend(WktimeHelper).validateERPPermission("M_BILL")}
	  menu.push :wkgltransaction, { :controller => 'wkgltransaction', :action => 'index' }, :caption => :label_accounting, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showAccounting }
	  menu.push :wkrfq, { :controller => 'wkrfq', :action => 'index' }, :caption => :label_purchasing, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showPurchase }
	  menu.push :wkproduct, { :controller => 'wkproduct', :action => 'index' }, :caption => :label_inventory, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showInventory }
      menu.push :wksurvey, { :controller => 'wksurvey', :action => 'index' }, :caption => :label_survey, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showSurvey }
	  menu.push :wkreport, { :controller => 'wkreport', :action => 'index' }, :caption => :label_report_plural, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).showReports && Object.new.extend(WktimeHelper).validateERPPermission("V_REPORT")}
	  menu.push :wkcrmenumeration, { :controller => 'wkcrmenumeration', :action => 'index' }, :caption => :label_settings, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission && Object.new.extend(WktimeHelper).hasSettingPerm }
	end

end