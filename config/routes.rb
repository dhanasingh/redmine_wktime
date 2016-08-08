  get 'wktime/index', :to => 'wktime#index'

  get 'wktime/getissues', :to => 'wktime#getissues'

  get 'wktime/getactivities', :to => 'wktime#getactivities'
  
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
	resources :wk_attendances, :controller => 'wkattendance'  do
	  collection { post :show }
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
  
  #For Report   
  get 'wkreport/index', :to => 'wkreport#index'
   
  get 'wkreport/reportattn', :to => 'wkreport#reportattn'  
  
  match 'updateClockInOut', :controller => 'wkattendance', :action => 'updateClockInOut', :via => [:get]
  
  get 'wkreport/getGroupMembers', :to => 'wkreport#getGroupMembers'
  
  get 'wkreport/getMembersbyGroup', :to => 'wkreport#getMembersbyGroup'
  
  get 'wkattendance/runPeriodEndProcess', :to => 'wkattendance#runPeriodEndProcess'
   
  post 'wkattendance/manualImport', :to => 'wkattendance#manualImport'
   
  get 'wkattendance/new', :to => 'wkattendance#new'
  