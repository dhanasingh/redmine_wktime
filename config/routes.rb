  get 'wktime/index', :to => 'wktime#index'

  get 'wktime/getissues', :to => 'wktime#getissues'

  get 'wktime/getactivities', :to => 'wktime#getactivities'

  get 'wktime/getclients', :to => 'wktime#getclients'

  get 'wktime/getuserclients', :to => 'wktime#getuserclients'

  get 'wktime/getuserissues', :to => 'wktime#getuserissues'
  
  get 'wktime/getusers', :to => 'wktime#getusers'

  get 'wktime/getMembersbyGroup', :to => 'wktime#getMembersbyGroup'
  
  get 'wktime/deleterow', :to => 'wktime#deleterow'

  get 'wktime/export', :to => 'wktime#export'
  
  match 'wktime/edit', :to => 'wktime#edit', :via => [:get, :post]

  get 'wktime/new', :to => 'wktime#new'
			  
  post 'wktime/update', :to => 'wktime#update'
			  
  delete 'wktime/destroy', :to => 'wktime#destroy'
  
  get 'wktime/getStatus', :to => 'wktime#getStatus' 
  
  get 'wktime/getTracker', :to => 'wktime#getTracker'
  
  delete 'wktime/deleteEntries', :to => 'wktime#deleteEntries'
  
  post 'wktime/sendSubReminderEmail', :to => 'wktime#sendSubReminderEmail'
  
  post 'wktime/sendApprReminderEmail', :to => 'wktime#sendApprReminderEmail'
  
  get 'wktime/testapi', :to => 'wktime#testapi' 
  
  #get 'wktime/updateAttendance', :to => 'wktime#updateAttendance'
match 'updateAttendance', :controller => 'wktime', :action => 'updateAttendance', :via => [:get]  
    
  get 'wktime/time_rpt', :to => 'wktime#time_rpt' 
  
  # For Supervisor feature
	get 'wktime/getMyReportUsers', :to => 'wktime#getMyReportUsers'
  
  #For Weekly expenses
  
  get 'wkexpense/index', :to => 'wkexpense#index'
  
  get 'wkexpense/new', :to => 'wkexpense#new'
  
  get 'wkexpense/getusers', :to => 'wkexpense#getusers'
  
  get 'wkexpense/getMembersbyGroup', :to => 'wkexpense#getMembersbyGroup'
  
  match 'wkexpense/edit', :to => 'wkexpense#edit', :via => [:get, :post]
  
  delete 'wkexpense/destroy', :to => 'wkexpense#destroy'
  
  post 'wkexpense/update', :to => 'wkexpense#update'
  
  get 'wkexpense/deleterow', :to => 'wkexpense#deleterow'

  get 'wkexpense/export', :to => 'wkexpense#export'
  
  get 'wkexpense/getissues', :to => 'wkexpense#getissues'

  get 'wkexpense/getactivities', :to => 'wkexpense#getactivities'

  get 'wkexpense/getclients', :to => 'wkexpense#getclients'

  get 'wkexpense/getuserclients', :to => 'wkexpense#getuserclients'

  get 'wkexpense/getuserissues', :to => 'wkexpense#getuserissues'
  
  post 'wkexpense/sendSubReminderEmail', :to => 'wkexpense#sendSubReminderEmail'
  
  post 'wkexpense/sendApprReminderEmail', :to => 'wkexpense#sendApprReminderEmail'  
  
  #For Weekly expense report
  
  get 'projects/wk_expense_entries/reportdetail' , :to => 'wkexpense#reportdetail'
  
  get 'projects/wk_expense_entries/report' , :to => 'wkexpense#report'
  
  delete 'wkexpense/deleteEntry', :to => 'wkexpense#deleteEntry'
  
  delete 'wkexpense/deleteEntries', :to => 'wkexpense#deleteEntries' 
  
  get 'wkexpense/time_rpt', :to => 'wkexpense#time_rpt' 
 
  resources :projects do	
	resources :wk_expense_entries, :controller => 'wkexpense' do
		collection do
			get 'reportdetail' 
			get 'report'
		end
	end   
  end
  
  #For Attendance
	resources :wk_attendances, :controller => 'wkimportattendance'  do
	  collection do
		post 'show'
	  end
	end
  get 'wkattendance/index', :to => 'wkattendance#index'
  
  post 'wkattendance/index', :to => 'wkattendance#index'
   
  match 'wkattendance/edit', :to => 'wkattendance#edit', :via => [:get, :post]
			  
  post 'wkattendance/update', :to => 'wkattendance#update'
   
  get 'wkattendance/getIssuesByProject', :to => 'wkattendance#getIssuesByProject'
   
  get 'wkattendance/getProjectByIssue', :to => 'wkattendance#getProjectByIssue' 

   get 'wkattendance/clockindex', :to => 'wkattendance#clockindex'
   
   post 'wkattendance/clockindex', :to => 'wkattendance#clockindex'

  match 'wkattendance/clockedit', :to => 'wkattendance#clockedit', :via => [:get, :post]  

get 'wkattendance/getGroupMembers', :to => 'wkattendance#getGroupMembers'
  
  get 'wkattendance/getMembersbyGroup', :to => 'wkattendance#getMembersbyGroup'
  
  post 'wkattendance/saveClockInOut', :to => 'wkattendance#saveClockInOut'
  
  #For Report   
  get 'wkreport/index', :to => 'wkreport#index'
   
  # get 'wkreport/reportattn', :to => 'wkreport#reportattn'  
  
  match 'updateClockInOut', :controller => 'wkattendance', :action => 'updateClockInOut', :via => [:get]
  
  get 'wkreport/getGroupMembers', :to => 'wkreport#getGroupMembers'
  
  get 'wkreport/getMembersbyGroup', :to => 'wkreport#getMembersbyGroup'
  
  get 'wkattendance/runPeriodEndProcess', :to => 'wkattendance#runPeriodEndProcess'
  
  #For payroll
  get 'wkpayroll/index', :to => 'wkpayroll#index'
  
  get 'wkpayroll/edit', :to => 'wkpayroll#edit'
  
  # get 'wkreport/payslip_rpt', :to => 'wkreport#payslip_rpt' 
  
  post 'wkpayroll/updateUserSalary', :to => 'wkpayroll#updateUserSalary'
  
  get 'wkpayroll/user_salary_settings', :to => 'wkpayroll#user_salary_settings'
  
  get 'wkpayroll/getGroupMembers', :to => 'wkpayroll#getGroupMembers'
  
  get 'wkpayroll/getMembersbyGroup', :to => 'wkpayroll#getMembersbyGroup'
  
  post 'wkpayroll/generatePayroll', :to => 'wkpayroll#generatePayroll'
  
   # get 'wkreport/payroll_rpt', :to => 'wkreport#payroll_rpt'
   
   get 'wkpayroll/usrsettingsindex', :to => 'wkpayroll#usrsettingsindex'
   
   post 'wkpayroll/usrsettingsindex', :to => 'wkpayroll#usrsettingsindex'
   
   get 'wkpayroll/payrollsettings', :to => 'wkpayroll#payrollsettings'

	 post 'wkpayroll/payrollsettings', :to => 'wkpayroll#payrollsettings'

	post 'wkpayroll/save_bulk_edit', :to => 'wkpayroll#save_bulk_edit'

    #For Billing
    get 'wkbilling/index', :to => 'wkbilling#index'	
	
	get 'wkcrmaccount/index', :to => 'wkcrmaccount#index'
	
	match 'wkcrmaccount/index', :to => 'wkcrmaccount#index', :via => [:get, :post]
	
	post 'wkcrmaccount/update', :to => 'wkcrmaccount#update'
	
	get 'wkcrmaccount/edit', :to => 'wkcrmaccount#edit'	
	
	delete 'wkcrmaccount/destroy', :to => 'wkcrmaccount#destroy'
	
	get 'wkcontracts/index', :to => 'wkcontracts#index'
	
	
	get 'wkaccountproject/index', :to => 'wkaccountproject#index'
	
	get 'wktax/index', :to => 'wktax#index'	
	
	get 'wkinvoice/index', :to => 'wkinvoice#index'	
	
	post 'wktax/index', :to => 'wktax#index'
	
	get 'wkinvoice/invoiceedit', :to => 'wkinvoice#invoiceedit'
	
	get 'wkinvoice/getAccountProjIds', :to => 'wkinvoice#getAccountProjIds'
    
	get 'wktax/edit', :to => 'wktax#edit'
	
	post 'wktax/update', :to => 'wktax#update'	
	
	delete 'wktax/destroy', :to => 'wktax#destroy'
	
	get 'wkinvoice/edit', :to => 'wkinvoice#edit'	
	
	post 'wkinvoice/update', :to => 'wkinvoice#update'
	
	delete 'wkinvoice/destroy', :to => 'wkinvoice#destroy'
	
	get 'wkaccountproject/edit', :to => 'wkaccountproject#edit'
	
	delete 'wkaccountproject/destroy', :to => 'wkaccountproject#destroy'
	
	post 'wkaccountproject/update', :to => 'wkaccountproject#update'
	
	get 'wkcontract/index', :to => 'wkcontract#index'
	
	get 'wkcontract/edit', :to => 'wkcontract#edit'
	
	post 'wkcontract/update', :to => 'wkcontract#update'
	
	delete 'wkcontract/destroy', :to => 'wkcontract#destroy'
	
	get 'wkinvoice/invreport', :to => 'wkinvoice#invreport' 

	# For Accounting
	
	get 'wkgltransaction/index', :to => 'wkgltransaction#index'	
	
	get 'wkgltransaction/edit', :to => 'wkgltransaction#edit'
	
	get 'wkgltransaction/update', :to => 'wkgltransaction#update'
	
	delete 'wkgltransaction/destroy', :to => 'wkgltransaction#destroy'
	
	get 'wkledger/index', :to => 'wkledger#index'
	
	get 'wkledger/edit', :to => 'wkledger#edit'
	
	get 'wkledger/update', :to => 'wkledger#update'
	
	delete 'wkledger/destroy', :to => 'wkledger#destroy'
  
	# get 'wkreport/pl_rpt', :to => 'wkreport#pl_rpt'
	
	# get 'wkreport/balance_sheet', :to => 'wkreport#balance_sheet'
	
	get 'wkbase/updateClockInOut', :to => 'wkbase#updateClockInOut'
	
	# For CRM
	
	get 'wkcrm/index', :to => 'wkcrm#index'
	
	get 'wklead/index', :to => 'wklead#index'
	
	post 'wklead/index', :to => 'wklead#index'
	
	post 'wklead/update', :to => 'wklead#update'
	
	get 'wklead/edit', :to => 'wklead#edit'	
	
	get 'wklead/show', :to => 'wklead#show'	
	
	get 'wklead/covert', :to => 'wklead#convert'
	
	delete 'wklead/destroy', :to => 'wklead#destroy'
	
	get 'wkopportunity/index', :to => 'wkopportunity#index'
	
	get 'wkcrmactivity/index', :to => 'wkcrmactivity#index'
	
	get 'wkcrmcontact/index', :to => 'wkcrmcontact#index'
	
    get 'wkcrmactivity/edit', :to => 'wkcrmactivity#edit'
	
	get 'wkcrm/getActRelatedIds', :to => 'wkcrm#getActRelatedIds'
	
	get 'wkcrmactivity/update', :to => 'wkcrmactivity#update'
	
	delete 'wkcrmactivity/destroy', :to => 'wkcrmactivity#destroy'
	
	get 'wkopportunity/edit', :to => 'wkopportunity#edit'
	
	get 'wkopportunity/update', :to => 'wkopportunity#update'

    delete 'wkopportunity/destroy', :to => 'wkopportunity#destroy'

	post 'wkopportunity/index', :to => 'wkopportunity#index'
	
	get 'wkcrmcontact/edit', :to => 'wkcrmcontact#edit'
	
	post 'wkcrmcontact/update', :to => 'wkcrmcontact#update'
	
	delete 'wkcrmcontact/destroy', :to => 'wkcrmcontact#destroy'
	
	get 'wkcrmenumeration/index', :to => 'wkcrmenumeration#index'
	
	get 'wkcrmenumeration/edit', :to => 'wkcrmenumeration#edit'
	
	post 'wkcrmenumeration/update', :to => 'wkcrmenumeration#update'
	
	delete 'wkcrmenumeration/destroy', :to => 'wkcrmenumeration#destroy' 
	
	get 'wkreport/report', :to => 'wkreport#report'
	
	# get 'wkreport/sales_act_rpt', :to => 'wkreport#sales_act_rpt'
	
	# For Payment
	
	get 'wkpayment/index', :to => 'wkpayment#index'
	
	get 'wkpayment/edit', :to => 'wkpayment#edit'	
	
	post 'wkpayment/update', :to => 'wkpayment#update'
	
	#get 'wkpayment/getBillableProjIds', :to => 'wkpayment#getBillableProjIds'
	
	get 'wkpaymententity/getBillableProjIds', :to => 'wkpaymententity#getBillableProjIds'
	
	#get 'wkpayment/showInvoices', :to => 'wkpayment#showInvoices'
	
	get 'wkpaymententity/showInvoices', :to => 'wkpaymententity#showInvoices'
	
	get 'wkexchangerate/index', :to => 'wkexchangerate#index'
	
	get 'wkexchangerate/update', :to => 'wkexchangerate#update'
	
	get 'wkinvoice/new', :to => 'wkinvoice#new' 
	
	# For Purchase
	
	get 'wkpurchase/index', :to => 'wkpurchase#index'
	
	get 'wkrfq/index', :to => 'wkrfq#index'
	
	post 'wkrfq/index', :to => 'wkrfq#index'
    
	get 'wkrfq/edit', :to => 'wkrfq#edit'
	
	post 'wkrfq/update', :to => 'wkrfq#update'	
	
	delete 'wkrfq/destroy', :to => 'wkrfq#destroy'
	
	get 'wkquote/index', :to => 'wkquote#index'
	
	get 'wkquote/new', :to => 'wkquote#new'
	
	get 'wkquote/edit', :to => 'wkquote#edit'
	
	post 'wkquote/update', :to => 'wkquote#update'	
	
	delete 'wkquote/destroy', :to => 'wkquote#destroy'
	
	get 'wkquote/invreport', :to => 'wkquote#invreport' 
	
	get 'wkpurchaseorder/index', :to => 'wkpurchaseorder#index'
	
	get 'wkpurchaseorder/new', :to => 'wkpurchaseorder#new'
	
	get 'wkpurchaseorder/edit', :to => 'wkpurchaseorder#edit'
	
	post 'wkpurchaseorder/update', :to => 'wkpurchaseorder#update'	
	
	delete 'wkpurchaseorder/destroy', :to => 'wkpurchaseorder#destroy'
	
	get 'wkpurchaseorder/invreport', :to => 'wkpurchaseorder#invreport' 
	
	get 'wksupplierinvoice/index', :to => 'wksupplierinvoice#index'
	
	get 'wksupplierinvoice/new', :to => 'wksupplierinvoice#new'
	
	get 'wksupplierinvoice/edit', :to => 'wksupplierinvoice#edit'
	
	post 'wksupplierinvoice/update', :to => 'wksupplierinvoice#update'	
	
	delete 'wksupplierinvoice/destroy', :to => 'wksupplierinvoice#destroy'
	
	get 'wksupplierinvoice/invreport', :to => 'wksupplierinvoice#invreport' 
	
	get 'wksupplierpayment/index', :to => 'wksupplierpayment#index'
	
	get 'wksupplieraccount/index', :to => 'wksupplieraccount#index'
	
	match 'wksupplieraccount/index', :to => 'wksupplieraccount#index', :via => [:get, :post]
	
	post 'wksupplieraccount/update', :to => 'wksupplieraccount#update'
	
	get 'wksupplieraccount/edit', :to => 'wksupplieraccount#edit'	
	
	delete 'wksupplieraccount/destroy', :to => 'wksupplieraccount#destroy'
	
	get 'wksuppliercontact/index', :to => 'wksuppliercontact#index'
	
	get 'wksuppliercontact/edit', :to => 'wksuppliercontact#edit'
	
	post 'wksuppliercontact/update', :to => 'wksuppliercontact#update'
	
	delete 'wksuppliercontact/destroy', :to => 'wksuppliercontact#destroy'
	
	get 'wkpurchaseorder/getRfqQuoteIds', :to => 'wkpurchaseorder#getRfqQuoteIds'
	
	get 'wksupplierinvoice/getRfqPoIds', :to => 'wksupplierinvoice#getRfqPoIds'
	
	get 'wksupplierpayment/edit', :to => 'wksupplierpayment#edit'
	
	post 'wksupplierpayment/update', :to => 'wksupplierpayment#update'
	
	get 'wktime/lockte', :to => 'wktime#lockte'
	
	 get 'wkexpense/lockte', :to => 'wkexpense#lockte'
	
	post 'wktime/lockupdate', :to => 'wktime#lockupdate'
	
	get 'wklocation/index', :to => 'wklocation#index' 
	
	#get 'wkproductcatagory/index', :to => 'wkproductcatagory#index'
	
	get 'wkproduct/index', :to => 'wkproduct#index'
	
	post 'wkproduct/index', :to => 'wkproduct#index'
    
	get 'wkproduct/edit', :to => 'wkproduct#edit'
	
	post 'wkproduct/update', :to => 'wkproduct#update'	
	
	delete 'wkproduct/destroy', :to => 'wkproduct#destroy'
    
	get 'wkproduct/category', :to => 'wkproduct#category'
	
	get 'wkproduct/updateCategory', :to => 'wkproduct#updateCategory'
	
	post 'wkproduct/updateCategory', :to => 'wkproduct#updateCategory'	
	
	#delete 'wkproduct/destroyCategory', :to => 'wkproduct#destroyCategory'
	
	get 'wkproductitem/index', :to => 'wkproductitem#index'
	
	get 'wkshipment/index', :to => 'wkshipment#index'
	
	get 'wkshipment/new', :to => 'wkshipment#new'
	
	get 'wkshipment/edit', :to => 'wkshipment#edit'
	
	post 'wkshipment/update', :to => 'wkshipment#update'
	
	delete 'wkshipment/destroy', :to => 'wkshipment#destroy'
	
	get 'wkunitofmeasurement/index', :to => 'wkunitofmeasurement#index'
	
	get 'wklogmaterial/modifyProductDD', :to => 'wklogmaterial#modifyProductDD'
	
	get 'wkshipment/populateProductItemDD', :to => 'wkshipment#populateProductItemDD'
	
	get 'wkproductitem/index', :to => 'wkproductitem#index'
	
	post 'wkproductitem/index', :to => 'wkproductitem#index'
    
	get 'wkproductitem/edit', :to => 'wkproductitem#edit'
	
	post 'wkproductitem/update', :to => 'wkproductitem#update'	
	
	delete 'wkproductitem/destroy', :to => 'wkproductitem#destroy'
    
	get 'wkproductitem/transfer', :to => 'wkproductitem#transfer'
	
	post 'wkproductitem/updateTransfer', :to => 'wkproductitem#updateTransfer'	
	
	get 'wkasset/index', :to => 'wkasset#index'
	
	post 'wkasset/index', :to => 'wkasset#index'
    
	get 'wkasset/edit', :to => 'wkasset#edit'
	
	post 'wkasset/update', :to => 'wkasset#update'	
	
	delete 'wkasset/destroy', :to => 'wkasset#destroy'
    
	get 'wkasset/transfer', :to => 'wkasset#transfer'
	
	post 'wkasset/updateTransfer', :to => 'wkasset#updateTransfer'	
	
	get 'wkbrand/index', :to => 'wkbrand#index'
	
	post 'wkbrand/index', :to => 'wkbrand#index'
    
	get 'wkbrand/edit', :to => 'wkbrand#edit'
	
	post 'wkbrand/update', :to => 'wkbrand#update'	
	
	delete 'wkbrand/destroy', :to => 'wkbrand#destroy'
    
	get 'wkbrand/edit_product_model', :to => 'wkbrand#edit_product_model'
	
	post 'wkbrand/updateProductModel', :to => 'wkbrand#updateProductModel'	
	
	delete 'wkbrand/destroyProductModel', :to => 'wkbrand#destroyProductModel'
	
	#get 'wkproductmodel/index', :to => 'wkproductmodel#index'
	
	#get 'wkproductattribute/index', :to => 'wkproductattribute#index'
	
	get 'wkattributegroup/index', :to => 'wkattributegroup#index'
	
	post 'wkattributegroup/index', :to => 'wkattributegroup#index'
    
	get 'wkattributegroup/edit', :to => 'wkattributegroup#edit'
	
	post 'wkattributegroup/update', :to => 'wkattributegroup#update'	
	
	delete 'wkattributegroup/destroy', :to => 'wkattributegroup#destroy'
    
	get 'wkattributegroup/edit_product_attribute', :to => 'wkattributegroup#edit_product_attribute'
	
	post 'wkattributegroup/updateProductAttribute', :to => 'wkattributegroup#updateProductAttribute'	
	
	delete 'wkattributegroup/destroyProductAttribute', :to => 'wkattributegroup#destroyProductAttribute'
	
	get 'wklocation/edit', :to => 'wklocation#edit'
	
	post 'wklocation/update', :to => 'wklocation#update'
	
	delete 'wklocation/destroy', :to => 'wklocation#destroy'
	
	get 'wkunitofmeasurement/update', :to => 'wkunitofmeasurement#update'
	
	get 'wkshipment/getSupplierInvoices', :to => 'wkshipment#getSupplierInvoices'
	
	get 'wkassetdepreciation/index', :to => 'wkassetdepreciation#index'
	
	post 'wkassetdepreciation/index', :to => 'wkassetdepreciation#index'
    
	get 'wkassetdepreciation/new', :to => 'wkassetdepreciation#new'
	
	get 'wkassetdepreciation/edit', :to => 'wkassetdepreciation#edit'
	
	post 'wkassetdepreciation/update', :to => 'wkassetdepreciation#update'	
	
	delete 'wkassetdepreciation/destroy', :to => 'wkassetdepreciation#destroy'
	
	get 'wkgrouppermission/index', :to => 'wkgrouppermission#index'
	
	get 'wkgrouppermission/edit', :to => 'wkgrouppermission#edit'
	
	post 'wkgrouppermission/update', :to => 'wkgrouppermission#update'
	
	get 'wkasset/getProductAsset', :to => 'wkasset#getProductAsset'
	
	get 'wkscheduling/index', :to => 'wkscheduling#index'	
	
	get 'wkshift/index', :to => 'wkshift#index'
	
	get 'wkshift/edit', :to => 'wkshift#edit'
	
	delete 'wkshift/destroy', :to => 'wkshift#destroy'
	
	get 'wkshift/update', :to => 'wkshift#update'
	
	post 'wkshift/shiftRoleUpdate', :to => 'wkshift#shiftRoleUpdate'
	
	get 'wkscheduling/edit', :to => 'wkscheduling#edit'
	
	post 'wkscheduling/update', :to => 'wkscheduling#update'
	
	get 'wkpublicholiday/index', :to => 'wkpublicholiday#index'
	
	post 'wkpublicholiday/update', :to => 'wkpublicholiday#update'
	
	get 'wklogmaterial/loadSpentType', :to => 'wklogmaterial#loadSpentType'
	
	get 'wkdashboard/index', :to => 'wkdashboard#index'
	
	get 'wkdashboard/graph', :to => 'wkdashboard#graph'
	
	get 'wksurvey/survey', :to => 'wksurvey#survey'
	
	get 'wksurvey/index', :to => 'wksurvey#index'

	get 'wksurvey/edit', :to => 'wksurvey#edit'

	get 'wksurvey/destroy', :to => 'wksurvey#destroy'

	post 'wksurvey/save_survey', :to => 'wksurvey#save_survey'

	post 'wksurvey/update_survey', :to => 'wksurvey#update_survey'

	get 'wksurvey/graph', :to => 'wksurvey#graph'

	get 'wksurvey/find_survey_for', :to => 'wksurvey#find_survey_for'

	get 'wksurvey/email_user', :to => 'wksurvey#email_user'

	get 'projects/:project_id/wksurvey', to: 'wksurvey#index'

	get 'wksurvey/user_survey', to: 'wksurvey#user_survey'

	post 'wksurvey/update_status', :to => 'wksurvey#update_status'

	get 'wksurvey/survey_response', :to => 'wksurvey#survey_response'

	get 'wksurvey/survey_result', :to => 'wksurvey#survey_result'

	get 'wkpayroll/export', :to => 'wkpayroll#export'

	get 'wkgltransaction/export', :to => 'wkgltransaction#export'

	resources :projects do
    resource :wkaccountproject, :only => [:index], :controller => :wkaccountproject do
      get :index
		end
 end