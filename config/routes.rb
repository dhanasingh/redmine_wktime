# For Dashboard

get 'wkdashboard', :to => 'wkdashboard#index'

get 'wkdashboard/graph', :to => 'wkdashboard#graph'

get 'wkdashboard/get_graphs', to: 'wkdashboard#get_graphs'

get 'wkdashboard/get_detail_report', to: 'wkdashboard#get_detail_report'

get 'wkdashboard/employee_dashboard', to: 'wkdashboard#employee_dashboard'

get 'wkdashboard/get_inv_detail_report', to: 'wkdashboard#get_inv_detail_report'

# Time

get 'wktime', :to => 'wktime#index'

get 'wktime/edit', :to => 'wktime#edit'

get 'wktime/:id/edit', :to => 'wktime#edit'

post 'wktime/update', :to => 'wktime#update'

delete 'wktime/:id/destroy', :to => 'wktime#destroy'

get 'wktime/get_issue_loggers', :to => 'wktime#get_issue_loggers'

get 'wktime/getissues', :to => 'wktime#getissues'

get 'wktime/getactivities', :to => 'wktime#getactivities'

get 'wktime/getclients', :to => 'wktime#getclients'

get 'wktime/getuserclients', :to => 'wktime#getuserclients'

get 'wktime/getuserissues', :to => 'wktime#getuserissues'

get 'wktime/getusers', :to => 'wktime#getusers'

get 'wktime/get_membersby_group', :to => 'wktime#get_membersby_group'

get 'wktime/deleterow', :to => 'wktime#deleterow'

get 'wktime/export', :to => 'wktime#export'

get 'wktime/get_status', :to => 'wktime#get_status'

get 'wktime/get_tracker', :to => 'wktime#get_tracker'

delete 'wktime/delete_entries', :to => 'wktime#delete_entries'

post 'wktime/send_sub_reminder_email', :to => 'wktime#send_sub_reminder_email'

post 'wktime/send_appr_reminder_email', :to => 'wktime#send_appr_reminder_email'

get 'wktime/testapi', :to => 'wktime#testapi'

get 'wktime/get_projects', :to => 'wktime#get_projects'

get 'update_attendance', :to => 'wktime#update_attendance'

get 'wktime/time_rpt', :to => 'wktime#time_rpt'

get 'wktime/lockte', :to => 'wktime#lockte'

post 'wktime/lockupdate', :to => 'wktime#lockupdate'

# For Time & Expense Supervisor feature

get 'wktime/get_my_report_users', :to => 'wktime#get_my_report_users'

get 'wktime/get_api_users', to: 'wktime#get_api_users'

# Expense

get 'wkexpense', :to => 'wkexpense#index'

get 'wkexpense/edit', :to => 'wkexpense#edit'

get 'wkexpense/:id/edit', :to => 'wkexpense#edit'

post 'wkexpense/update', :to => 'wkexpense#update'

delete 'wkexpense/:id/destroy', :to => 'wkexpense#destroy'

get 'wkexpense/new', :to => 'wkexpense#new'

get 'wkexpense/getusers', :to => 'wkexpense#getusers'

get 'wkexpense/get_membersby_group', :to => 'wkexpense#get_membersby_group'

get 'wkexpense/deleterow', :to => 'wkexpense#deleterow'

get 'wkexpense/export', :to => 'wkexpense#export'

get 'wkexpense/getissues', :to => 'wkexpense#getissues'

get 'wkexpense/getactivities', :to => 'wkexpense#getactivities'

get 'wkexpense/getclients', :to => 'wkexpense#getclients'

get 'wkexpense/getuserclients', :to => 'wkexpense#getuserclients'

get 'wkexpense/getuserissues', :to => 'wkexpense#getuserissues'

post 'wkexpense/send_sub_reminder_email', :to => 'wkexpense#send_sub_reminder_email'

post 'wkexpense/send_appr_reminder_email', :to => 'wkexpense#send_appr_reminder_email'

delete 'wkexpense/delete_entry', :to => 'wkexpense#delete_entry'

delete 'wkexpense/delete_entries', :to => 'wkexpense#delete_entries'

get 'wkexpense/time_rpt', :to => 'wkexpense#time_rpt'

get 'wkexpense/get_currency', :to => 'wkexpense#get_currency'

get 'wkexpense/lockte', :to => 'wkexpense#lockte'

resources :projects do
	resources :wk_expense_entries, :controller => 'wkexpense' do
		collection do
			get 'reportdetail'
			get 'report'
		end
	end
end

#For Weekly expense report

get 'projects/wk_expense_entries/reportdetail' , :to => 'wkexpense#reportdetail'

get 'projects/wk_expense_entries/report' , :to => 'wkexpense#report'

#For HR Attendance (Leave & Clock)

resources :wk_attendances, :controller => 'wkimportattendance'  do
	collection do
		post 'show'
	end
end

get 'wkattendance', :to => 'wkattendance#index'

post 'wkattendance', :to => 'wkattendance#index'

get 'wkattendance/edit', :to => 'wkattendance#edit'

post 'wkattendance/update', :to => 'wkattendance#update'

get 'wkattendance/get_issues_by_project', :to => 'wkattendance#get_issues_by_project'

get 'wkattendance/get_project_by_issue', :to => 'wkattendance#get_project_by_issue'

get 'wkattendance/clockindex', :to => 'wkattendance#clockindex'

get 'wkattendance/:id/clockedit', :to => 'wkattendance#clockedit'

get 'wkattendance/clockedit', :to => 'wkattendance#clockedit'

get 'wkattendance/get_group_members', :to => 'wkattendance#get_group_members'

get 'wkattendance/get_membersby_group', :to => 'wkattendance#get_membersby_group'

post 'wkattendance/save_clock_in_out', :to => 'wkattendance#save_clock_in_out'

post 'wkattendance/save_bulk_edit', :to => 'wkattendance#save_bulk_edit'

get 'wkattendance/get_clock_hours', :to => 'wkattendance#get_clock_hours'

get 'wkattendance/leavesettings', to: 'wkattendance#leavesettings'

post 'wkattendance/leavesettings', to: 'wkattendance#leavesettings'

get 'wkattendance/run_period_end_process', :to => 'wkattendance#run_period_end_process'

# For HR Public Holiday

get 'wkpublicholiday', :to => 'wkpublicholiday#index'

post 'wkpublicholiday/update', :to => 'wkpublicholiday#update'

#For HR Leave Request

get 'wkleaverequest', :to => 'wkleaverequest#index'

get 'wkleaverequest/:id/edit', :to => 'wkleaverequest#edit'

get 'wkleaverequest/edit', :to => 'wkleaverequest#edit'

post 'wkleaverequest/save', :to => 'wkleaverequest#save'

get 'wkleaverequest/get_leave_available_hours', :to => 'wkleaverequest#get_leave_available_hours'

get 'wkleaverequest/get_leave_options', :to => 'wkleaverequest#get_leave_options'

#For HR payroll

get 'wkpayroll', :to => 'wkpayroll#index'

get 'wkpayroll/edit', :to => 'wkpayroll#edit'

post 'wkpayroll/update_user_salary', :to => 'wkpayroll#update_user_salary'

get 'wkpayroll/user_salary_settings', :to => 'wkpayroll#user_salary_settings'

get 'wkpayroll/get_group_members', :to => 'wkpayroll#get_group_members'

get 'wkpayroll/get_membersby_group', :to => 'wkpayroll#get_membersby_group'

post 'wkpayroll/generate_payroll', :to => 'wkpayroll#generate_payroll'

get 'wkpayroll/usrsettingsindex', :to => 'wkpayroll#usrsettingsindex'

match 'wkpayroll/payrollsettings', :to => 'wkpayroll#payrollsettings', :via => [:get, :post]

post 'wkpayroll/save_bulk_edit', :to => 'wkpayroll#save_bulk_edit'

get 'wkpayroll/export', :to => 'wkpayroll#export'

get 'wkpayroll/income_tax', :to => 'wkpayroll#income_tax'

post 'wkpayroll/income_tax', :to => 'wkpayroll#income_tax'

get 'wkpayroll/get_recursive_comp', :to => 'wkpayroll#get_recursive_comp'

delete 'wkpayroll/destroy', to: 'wkpayroll#destroy'

# For HR Scheduling

get 'wkscheduling', :to => 'wkscheduling#index'

get 'wkscheduling/edit', :to => 'wkscheduling#edit'

post 'wkscheduling/update', :to => 'wkscheduling#update'

# For HR Scheduling Shift

get 'wkshift', :to => 'wkshift#index'

get 'wkshift/edit', :to => 'wkshift#edit'

get 'wkshift/:id/edit', :to => 'wkshift#edit'

get 'wkshift/update', :to => 'wkshift#update'

post 'wkshift/shift_role_update', :to => 'wkshift#shift_role_update'

# For HR Skills

get 'wkskill', :to => 'wkskill#index'

get 'projects/:project_id/wkskill', :to => 'wkskill#index'

get 'wkskill/edit', :to => 'wkskill#edit'

get 'wkskill/:id/edit', :to => 'wkskill#edit'

post 'wkskill/save', :to => 'wkskill#save'

delete 'wkskill/:id', :to => 'wkskill#destroy'

# For HR Referrals

get 'wkreferrals', to: 'wkreferrals#index'

get 'wkreferrals/edit', to: 'wkreferrals#edit'

get 'wkreferrals/:id/edit', to: 'wkreferrals#edit'

post 'wkreferrals/update', to: 'wkreferrals#update'

delete 'wkreferrals/:id', to: 'wkreferrals#destroy'

get 'wkreferrals/convert', to: 'wkreferrals#convert'

get 'wkreferrals/get_emp_details', to: 'wkreferrals#get_emp_details'

# For HR Employee

get 'wkuser', :to => 'wkuser#index'

get 'wkuser/:id/edit', :to => 'wkuser#edit'

post 'wkuser/:id/save', :to => 'wkuser#save'

#For CRM Lead

get 'wklead', :to => 'wklead#index'

# get 'wklead/:id', :to => 'wklead#show'

get 'wklead/:id/edit', :to => 'wklead#edit'

get 'wklead/edit', :to => 'wklead#edit'

post 'wklead/update', :to => 'wklead#update'

get 'wklead/covert', :to => 'wklead#convert'

delete 'wklead/:id', :to => 'wklead#destroy'

# For CRM Account

get 'wkcrmaccount', :to => 'wkcrmaccount#index'

post 'wkcrmaccount/update', :to => 'wkcrmaccount#update'

get 'wkcrmaccount/:id/edit', :to => 'wkcrmaccount#edit'

get 'wkcrmaccount/edit', :to => 'wkcrmaccount#edit'

delete 'wkcrmaccount/:id', :to => 'wkcrmaccount#destroy'

# For CRM Opportunity

get 'wkopportunity', :to => 'wkopportunity#index'

get 'wkopportunity/edit', :to => 'wkopportunity#edit'

get 'wkopportunity/:id/edit', :to => 'wkopportunity#edit'

get 'wkopportunity/update', :to => 'wkopportunity#update'

delete 'wkopportunity/:id', :to => 'wkopportunity#destroy'

# For CRM

get 'wkcrmactivity', :to => 'wkcrmactivity#index'

get 'wkcrmactivity/:id/edit', :to => 'wkcrmactivity#edit'

get 'wkcrmactivity/edit', :to => 'wkcrmactivity#edit'

post 'wkcrmactivity/update', :to => 'wkcrmactivity#update'

delete 'wkcrmactivity/:id', :to => 'wkcrmactivity#destroy'

# For CRM Contact

get 'wkcrmcontact', :to => 'wkcrmcontact#index'

get 'wkcrmcontact/edit', :to => 'wkcrmcontact#edit'

get 'wkcrmcontact/:id/edit', :to => 'wkcrmcontact#edit'

post 'wkcrmcontact/update', :to => 'wkcrmcontact#update'

delete 'wkcrmcontact/:id', :to => 'wkcrmcontact#destroy'

# For CRM Account Project

resources :projects do
	resource :wkaccountproject, :only => [:index], :controller => :wkaccountproject do
		get :index
	end
end

get 'wkaccountproject/edit', :to => 'wkaccountproject#edit'

get 'wkaccountproject/:id/edit', :to => 'wkaccountproject#edit'

delete 'wkaccountproject/:id', :to => 'wkaccountproject#destroy'

post 'wkaccountproject/update', :to => 'wkaccountproject#update'


# CRM

get 'wkcrm/get_act_related_ids', :to => 'wkcrm#get_act_related_ids'

get 'wkcrm/get_crm_users', to: 'wkcrm#get_crm_users'


# For CRM Sales Quote

get 'wksalesquote', :to => 'wksalesquote#index'

get 'wksalesquote/new', :to => 'wksalesquote#new'

get 'wksalesquote/edit', :to => 'wksalesquote#edit'

get 'wksalesquote/:id/edit', :to => 'wksalesquote#edit'

post 'wksalesquote/update', :to => 'wksalesquote#update'

delete 'wksalesquote/:id', :to => 'wksalesquote#destroy'

get 'wksalesquote/invreport', :to => 'wksalesquote#invreport'

get 'wksalesquote/export', :to => 'wksalesquote#export'

# For Billing Invoice

get 'wkinvoice', :to => 'wkinvoice#index'

get 'wkinvoice/new', :to => 'wkinvoice#new'

get 'wkinvoice/edit', :to => 'wkinvoice#edit'

get 'wkinvoice/:id/edit', :to => 'wkinvoice#edit'

post 'wkinvoice/update', :to => 'wkinvoice#update'

delete 'wkinvoice/:id', :to => 'wkinvoice#destroy'

get 'wkinvoice/invoiceedit', :to => 'wkinvoice#invoiceedit'

get 'wkinvoice/get_account_proj_ids', :to => 'wkinvoice#get_account_proj_ids'

get 'wkinvoice/get_quantity_details', to: 'wkinvoice#get_quantity_details'

get 'wkinvoice/get_unbilled_qty_details', to: 'wkinvoice#get_unbilled_qty_details'

get 'wkinvoice/generate_time_entries', to: 'wkinvoice#generate_time_entries'

get 'wkinvoice/invoice_components', to: 'wkinvoice#invoice_components'

post 'wkinvoice/save_invoice_components', to: 'wkinvoice#save_invoice_components'

get 'wkinvoice/invreport', :to => 'wkinvoice#invreport'

get 'wkinvoice/get_inv_proj', :to => 'wkinvoice#get_inv_proj'

get 'wkinvoice/export', :to => 'wkinvoice#export'

get 'wkorderentity/get_product_tax', to: 'wkorderentity#get_product_tax'

get 'wkorderentity/get_project_tax', to: 'wkorderentity#get_project_tax'

get 'wkinvoice/get_issue_dd', to: 'wkinvoice#get_issue_dd'

get 'wksalesquote/get_issue_dd', to: 'wksalesquote#get_issue_dd'

get 'wkquote/get_issue_dd', to: 'wkquote#get_issue_dd'

get 'wkpurchaseorder/get_issue_dd', to: 'wkpurchaseorder#get_issue_dd'

get 'wksupplierinvoice/get_issue_dd', to: 'wksupplierinvoice#get_issue_dd'

get 'wkorderentity/check_qty', to: 'wkorderentity#check_qty'

get 'wkorderentity/get_inv_detals', to: 'wkorderentity#get_inv_detals'

# For Billing Payment

get 'wkpayment', :to => 'wkpayment#index'

get 'wkpayment/edit', :to => 'wkpayment#edit'

get 'wkpayment/:id/edit', :to => 'wkpayment#edit'

post 'wkpayment/update', :to => 'wkpayment#update'

delete 'wkpayment/:id', to: 'wkpayment#destroy'

get 'wkpaymententity/get_billable_proj_ids', :to => 'wkpaymententity#get_billable_proj_ids'

get 'wkpaymententity/show_invoices', :to => 'wkpaymententity#show_invoices'

# For Billing Contracts

get 'wkcontract', :to => 'wkcontract#index'

get 'wkcontract/edit', :to => 'wkcontract#edit'

get 'wkcontract/:id/edit', :to => 'wkcontract#edit'

post 'wkcontract/update', :to => 'wkcontract#update'

delete 'wkcontract/:id', :to => 'wkcontract#destroy'

# For Accounting Transaction

get 'wkgltransaction', :to => 'wkgltransaction#index'

get 'wkgltransaction/edit', :to => 'wkgltransaction#edit'

get 'wkgltransaction/:id/edit', :to => 'wkgltransaction#edit'

get 'wkgltransaction/update', :to => 'wkgltransaction#update'

delete 'wkgltransaction/:id', :to => 'wkgltransaction#destroy'

get 'wkgltransaction/graph', to: 'wkgltransaction#graph'

post 'wkgltransaction/update', to: 'wkgltransaction#update'

get 'wkgltransaction/export', :to => 'wkgltransaction#export'

# For Accounting Ledger

get 'wkledger', :to => 'wkledger#index'

get 'wkledger/edit', :to => 'wkledger#edit'

get 'wkledger/:id/edit', :to => 'wkledger#edit'

get 'wkledger/update', :to => 'wkledger#update'

delete 'wkledger/:id', :to => 'wkledger#destroy'

# For Purchasing RFQ

get 'wkrfq', :to => 'wkrfq#index'

post 'wkrfq/index', :to => 'wkrfq#index'

get 'wkrfq/edit', :to => 'wkrfq#edit'

get 'wkrfq/:id/edit', :to => 'wkrfq#edit'

post 'wkrfq/update', :to => 'wkrfq#update'

delete 'wkrfq/:id', :to => 'wkrfq#destroy'

# For Purchasing Quote

get 'wkquote', :to => 'wkquote#index'

get 'wkquote/new', :to => 'wkquote#new'

get 'wkquote/edit', :to => 'wkquote#edit'

get 'wkquote/:id/edit', :to => 'wkquote#edit'

post 'wkquote/update', :to => 'wkquote#update'

delete 'wkquote/:id', :to => 'wkquote#destroy'

get 'wkquote/invreport', :to => 'wkquote#invreport'

get 'wkquote/export', :to => 'wkquote#export'

# For Purchasing Purchase Order

get 'wkpurchaseorder', :to => 'wkpurchaseorder#index'

get 'wkpurchaseorder/new', :to => 'wkpurchaseorder#new'

get 'wkpurchaseorder/edit', :to => 'wkpurchaseorder#edit'

get 'wkpurchaseorder/:id/edit', :to => 'wkpurchaseorder#edit'

post 'wkpurchaseorder/update', :to => 'wkpurchaseorder#update'

delete 'wkpurchaseorder/:id', :to => 'wkpurchaseorder#destroy'

get 'wkpurchaseorder/invreport', :to => 'wkpurchaseorder#invreport'

get 'wkpurchaseorder/get_rfq_quote_ids', :to => 'wkpurchaseorder#get_rfq_quote_ids'

get 'wkpurchaseorder/export', :to => 'wkpurchaseorder#export'

# For Purchasing Supplier Invoice

get 'wksupplierinvoice', :to => 'wksupplierinvoice#index'

get 'wksupplierinvoice/new', :to => 'wksupplierinvoice#new'

get 'wksupplierinvoice/edit', :to => 'wksupplierinvoice#edit'

get 'wksupplierinvoice/:id/edit', :to => 'wksupplierinvoice#edit'

post 'wksupplierinvoice/update', :to => 'wksupplierinvoice#update'

delete 'wksupplierinvoice/:id', :to => 'wksupplierinvoice#destroy'

get 'wksupplierinvoice/invreport', :to => 'wksupplierinvoice#invreport'

get 'wksupplierinvoice/get_rfq_po_ids', :to => 'wksupplierinvoice#get_rfq_po_ids'

get 'wksupplierinvoice/export', :to => 'wksupplierinvoice#export'

# For Purchasing Supplier Payment

get 'wksupplierpayment', :to => 'wksupplierpayment#index'

get 'wksupplierpayment/edit', :to => 'wksupplierpayment#edit'

get 'wksupplierpayment/:id/edit', :to => 'wksupplierpayment#edit'

post 'wksupplierpayment/update', :to => 'wksupplierpayment#update'

delete 'wksupplierpayment/:id', to: 'wksupplierpayment#destroy'

# For Purchasing Supplier Account

get 'wksupplieraccount', :to => 'wksupplieraccount#index'

get 'wksupplieraccount/edit', :to => 'wksupplieraccount#edit'

get 'wksupplieraccount/:id/edit', :to => 'wksupplieraccount#edit'

post 'wksupplieraccount/update', :to => 'wksupplieraccount#update'

delete 'wksupplieraccount/:id', :to => 'wksupplieraccount#destroy'

# For Purchasing Supplier Contact

get 'wksuppliercontact', :to => 'wksuppliercontact#index'

get 'wksuppliercontact/edit', :to => 'wksuppliercontact#edit'

get 'wksuppliercontact/:id/edit', :to => 'wksuppliercontact#edit'

post 'wksuppliercontact/update', :to => 'wksuppliercontact#update'

delete 'wksuppliercontact/:id', :to => 'wksuppliercontact#destroy'

# For Inventory Product

get 'wkproduct', :to => 'wkproduct#index'

post 'wkproduct/index', :to => 'wkproduct#index'

get 'wkproduct/edit', :to => 'wkproduct#edit'

get 'wkproduct/:id/edit', :to => 'wkproduct#edit'

post 'wkproduct/update', :to => 'wkproduct#update'

delete 'wkproduct/:id', :to => 'wkproduct#destroy'

get 'wkproduct/category', :to => 'wkproduct#category'

get 'wkproduct/update_category', :to => 'wkproduct#update_category'

post 'wkproduct/update_category', :to => 'wkproduct#update_category'

# For Inventory Brand

get 'wkbrand', :to => 'wkbrand#index'

post 'wkbrand/index', :to => 'wkbrand#index'

get 'wkbrand/edit', :to => 'wkbrand#edit'

get 'wkbrand/:id/edit', :to => 'wkbrand#edit'

post 'wkbrand/update', :to => 'wkbrand#update'

delete 'wkbrand/:id', :to => 'wkbrand#destroy'

get 'wkbrand/edit_product_model', :to => 'wkbrand#edit_product_model'

get 'wkbrand/:id/edit_product_model', :to => 'wkbrand#edit_product_model'

post 'wkbrand/update_product_model', :to => 'wkbrand#update_product_model'

delete 'wkbrand/:id/destroy_product_model', :to => 'wkbrand#destroy_product_model'

# For Inventory Attributes

get 'wkattributegroup', :to => 'wkattributegroup#index'

post 'wkattributegroup/index', :to => 'wkattributegroup#index'

get 'wkattributegroup/edit', :to => 'wkattributegroup#edit'

get 'wkattributegroup/:id/edit', :to => 'wkattributegroup#edit'

post 'wkattributegroup/update', :to => 'wkattributegroup#update'

delete 'wkattributegroup/:id', :to => 'wkattributegroup#destroy'

get 'wkattributegroup/edit_product_attribute', :to => 'wkattributegroup#edit_product_attribute'

get 'wkattributegroup/:id/edit_product_attribute', :to => 'wkattributegroup#edit_product_attribute'

post 'wkattributegroup/update_product_attribute', :to => 'wkattributegroup#update_product_attribute'

delete 'wkattributegroup/:id/destroy_product_attribute', :to => 'wkattributegroup#destroy_product_attribute'

	# For Inventory Unit of Measurement

	get 'wkunitofmeasurement', :to => 'wkunitofmeasurement#index'

	get 'wkunitofmeasurement/update', :to => 'wkunitofmeasurement#update'

# For Inventory Product Item

get 'wkproductitem', :to => 'wkproductitem#index'

post 'wkproductitem/index', :to => 'wkproductitem#index'

get 'wkproductitem/edit', :to => 'wkproductitem#edit'

get 'wkproductitem/:id/edit', :to => 'wkproductitem#edit'

post 'wkproductitem/update', :to => 'wkproductitem#update'

delete 'wkproductitem/destroy', :to => 'wkproductitem#destroy'

get 'wkproductitem/transfer', :to => 'wkproductitem#transfer'

post 'wkproductitem/update_transfer', :to => 'wkproductitem#update_transfer'

get 'wkproductitem/:id/get_material_entries', to: 'wkproductitem#get_material_entries'

get 'wkproductitem/assemble_item', :to => 'wkproductitem#assemble_item'

get 'wkproductitem/get_item_details', :to => 'wkproductitem#get_item_details'

# For Inventory Receipt

get 'wkshipment', :to => 'wkshipment#index'

get 'wkshipment/new', :to => 'wkshipment#new'

get 'wkshipment/edit', :to => 'wkshipment#edit'

get 'wkshipment/:id/edit', :to => 'wkshipment#edit'

post 'wkshipment/update', :to => 'wkshipment#update'

delete 'wkshipment/:id', :to => 'wkshipment#destroy'

get 'wkshipment/load_product_items', :to => 'wkshipment#load_product_items'

get 'wkshipment/get_supplier_invoices', :to => 'wkshipment#get_supplier_invoices'

get 'wkshipment/get_product_uom', to: 'wkshipment#get_product_uom'

get 'wkshipment/check_quantity', to: 'wkshipment#check_quantity'

# For Inventory Delivery

get 'wkdelivery', to: 'wkdelivery#index'

get 'wkdelivery/edit', to: 'wkdelivery#edit'

get 'wkdelivery/:id/edit', to: 'wkdelivery#edit'

post 'wkdelivery/update', to: 'wkdelivery#update'

delete 'wkdelivery/:id', to: 'wkdelivery#destroy'

get 'wkdelivery/load_product_items', to: 'wkdelivery#load_product_items'

get 'wkdelivery/delivery_slip', to: 'wkdelivery#delivery_slip'

get 'wkdelivery/get_invoice_no', to: 'wkdelivery#get_invoice_no'

# For Inventory Assets

get 'wkasset', :to => 'wkasset#index'

post 'wkasset/index', :to => 'wkasset#index'

get 'wkasset/edit', :to => 'wkasset#edit'

get 'wkasset/:id/edit', :to => 'wkasset#edit'

post 'wkasset/update', :to => 'wkasset#update'

delete 'wkasset/destroy', :to => 'wkasset#destroy'

get 'wkasset/transfer', :to => 'wkasset#transfer'

post 'wkasset/update_transfer', :to => 'wkasset#update_transfer'

get 'wkasset/dispose_asset', to: 'wkasset#dispose_asset'

post 'wkasset/update_disposed_asset', to: 'wkasset#update_disposed_asset'

get 'wkasset/get_product_asset', :to => 'wkasset#get_product_asset'

get 'wkasset/:id/get_material_entries', to: 'wkasset#get_material_entries'

# For Inventory Depreciation

get 'wkassetdepreciation', :to => 'wkassetdepreciation#index'

post 'wkassetdepreciation/index', :to => 'wkassetdepreciation#index'

get 'wkassetdepreciation/new', :to => 'wkassetdepreciation#new'

get 'wkassetdepreciation/edit', :to => 'wkassetdepreciation#edit'

get 'wkassetdepreciation/:id/edit', :to => 'wkassetdepreciation#edit'

post 'wkassetdepreciation/update', :to => 'wkassetdepreciation#update'

delete 'wkassetdepreciation/:id', :to => 'wkassetdepreciation#destroy'


# For Survey

get 'wksurvey', :to => 'wksurvey#index'

get 'wksurvey/edit', :to => 'wksurvey#edit'

get 'wksurvey/:id/edit', :to => 'wksurvey#edit'

get 'wksurvey/:id/survey_response', :to => 'wksurvey#survey_response'

get 'wksurvey/:id/survey_result', :to => 'wksurvey#survey_result'

post 'wksurvey/save_survey', :to => 'wksurvey#save_survey'

post 'wksurvey/update_survey', :to => 'wksurvey#update_survey'

get 'projects/:project_id/wksurvey', to: 'wksurvey#index'

get 'wksurvey/user_survey', to: 'wksurvey#user_survey'

get 'wksurvey/:id/survey', :to => 'wksurvey#survey'

delete 'wksurvey/:id', :to => 'wksurvey#destroy'

get 'wksurvey/graph', :to => 'wksurvey#graph'

get 'wksurvey/find_survey_for', :to => 'wksurvey#find_survey_for'

get 'wksurvey/email_user', :to => 'wksurvey#email_user'

post 'wksurvey/update_status', :to => 'wksurvey#update_status'

post 'wksurvey/close_current_response', :to => 'wksurvey#close_current_response'

get 'wksurvey/print_survey_result', :to => 'wksurvey#print_survey_result'

get 'wksurvey/print_survey', :to => 'wksurvey#print_survey'

#For Report

get 'wkreport', :to => 'wkreport#index'

get 'wkreport/get_group_members', :to => 'wkreport#get_group_members'

get 'wkreport/get_membersby_group', :to => 'wkreport#get_membersby_group'

get 'wkreport/export', to: 'wkreport#export'

get 'wkreport/report', :to => 'wkreport#report'

get 'wkreport/get_reports', to: 'wkreport#get_reports'

get 'wkreport/get_report_data', to: 'wkreport#get_report_data'

# For Settings Enumeration

get 'wkcrmenumeration', :to => 'wkcrmenumeration#index'

get 'wkcrmenumeration/:id/edit', :to => 'wkcrmenumeration#edit'

get 'wkcrmenumeration/edit', :to => 'wkcrmenumeration#edit'

post 'wkcrmenumeration/update', :to => 'wkcrmenumeration#update'

delete 'wkcrmenumeration/:id', :to => 'wkcrmenumeration#destroy'

get 'wkcrmenumeration/get_crm_enumerations', to: 'wkcrmenumeration#get_crm_enumerations'

get 'wkcrmenumeration/get_crm_enumerations', :to => 'wkcrmenumeration#get_crm_enumerations'

# For Settings Location

get 'wklocation', :to => 'wklocation#index'

get 'wklocation/edit', :to => 'wklocation#edit'

get 'wklocation/:id/edit', :to => 'wklocation#edit'

post 'wklocation/update', :to => 'wklocation#update'

delete 'wklocation/:id', :to => 'wklocation#destroy'

get 'wklocation/getlocations', to: 'wklocation#getlocations'

get 'wklocation/getlocations', :to => 'wklocation#getlocations'

# For Settings Tax

get 'wktax', :to => 'wktax#index'

get 'wktax/edit', :to => 'wktax#edit'

get 'wktax/:id/edit', :to => 'wktax#edit'

post 'wktax/update', :to => 'wktax#update'

delete 'wktax/:id', :to => 'wktax#destroy'

# For Settings Exchange Rate

get 'wkexchangerate', :to => 'wkexchangerate#index'

get 'wkexchangerate/update', :to => 'wkexchangerate#update'

# For Settings Permission

get 'wkgrouppermission', :to => 'wkgrouppermission#index'

post 'wkgrouppermission/update', :to => 'wkgrouppermission#update'

# For Settings Notifications

get 'wknotification', :to => 'wknotification#index'

post 'wknotification/update', :to => 'wknotification#update'

get 'wknotification/update_user_notification', to: 'wknotification#update_user_notification'

post 'wknotification/mark_read_notification', to: 'wknotification#mark_read_notification'

# Others Routes
# Base Controller

get 'wkbase/get_wkuser_data', to: 'wkbase#get_wkuser_data'

get 'wkbase/update_wkuser_data', to: 'wkbase#update_wkuser_data'

get 'wkbase/update_wkuser_val', to: 'wkbase#update_wkuser_val'

get 'wkbase/my_account', to: 'wkbase#my_account'

get 'wkbase/get_groups', to: 'wkbase#get_groups'

post 'wkbase/update_clockinout', :to => 'wkbase#update_clockinout'

get 'wkbase/get_user_permissions', :to => 'wkbase#get_user_permissions'

get 'wkbase/save_issue_log', :to => 'wkbase#save_issue_log'

# For Documents

get 'wkdocument/new', :to => 'wkdocument#new'

post 'wkdocument/save', :to => 'wkdocument#save'

get 'wkdocument/download/:id', :to => 'wkdocument#download'

delete 'wkdocument/:id', :to => 'wkdocument#destroy'

get 'wkdocument/:id', :to => 'wkdocument#view'

get 'wkdocument/download/:id/:filename', :to => 'wkdocument#download', :id => /\d+/, :filename => /.*/, :as => 'download_location_attachment'

# Log Material

get 'wklogmaterial/index', to: 'wklogmaterial#index'

post 'wklogmaterial/create', to: 'wklogmaterial#create'

post 'wklogmaterial/update', to: 'wklogmaterial#update'

get 'wklogmaterial/load_spent_type', :to => 'wklogmaterial#load_spent_type'

get 'wklogmaterial/spent_log_edit', :to => 'wklogmaterial#spent_log_edit'

get 'wklogmaterial/modify_product_dd', :to => 'wklogmaterial#modify_product_dd'

get 'attachments/:object_type/:object_id/edit', :to => 'attachments#edit_all', :as => :wk_object_attachments_edit

# For CRM Dashboard

get 'wkcrmdashboard', :to => 'wkcrmdashboard#index'

get 'wkcrmdashboard/graph', :to => 'wkcrmdashboard#graph'

get 'wkcrmdashboard/get_graphs', to: 'wkcrmdashboard#get_graphs'

get 'wkcrmdashboard/get_detail_report', to: 'wkcrmdashboard#get_detail_report'

match  'wkreferrals/:id/hired_employee', to: 'wkreferrals#hired_employee', via: [:get, :post]