class WkaccountprojectController < WkbillingController

before_filter :require_login

    def index
		@accountproject = nil
		sqlwhere = ""
		set_filter_session
		accountId = session[:accountproject][:account_id]
		projectId	= session[:accountproject][:project_id]
		
		if accountId.blank? &&  !projectId.blank?
			sqlwhere = "project_id = #{projectId}"
		end
		if !accountId.blank? &&  projectId.blank?
			sqlwhere = "account_id = #{accountId}"
		end
		if !accountId.blank? &&  !projectId.blank?
			sqlwhere = "account_id = #{accountId} and project_id = #{projectId}"
		end
		
		if accountId.blank? && projectId.blank?
			entries = WkAccountProject.all
		else
			entries = WkAccountProject.where(sqlwhere)
		end	
		formPagination(entries)	
    end
	
	def edit
		@accProjEntry = nil
		unless params[:acc_project_id].blank?
			@accProjEntry = WkAccountProject.find(params[:acc_project_id].to_i)			
			@wkbillingschedule = WkBillingSchedule.where("account_project_id = ? ", params[:acc_project_id].to_i)
		end		
		taxentry = WkTax.all
		@taxentry = taxentry.collect{|m| [ m.name, m.id ] }
		stax = @accProjEntry.taxes
		@selectedtax = stax.map { |r| r.id } #stax.collect{|m| [  m.id ] }
	end
	
	def update
		errorMsg = nil
		wkaccountproject = nil
		wkbillingschedule = nil
		wkaccprojecttax = nil
		arrId = []
		if !params[:accountProjectId].blank?
			wkaccountproject = WkAccountProject.find(params[:accountProjectId].to_i)
		else
			wkaccountproject = WkAccountProject.new
		end
		
		wkaccountproject.project_id = params[:project_id].to_i
		wkaccountproject.account_id = params[:account_id].to_i
		wkaccountproject.apply_tax = params[:applytax]
		wkaccountproject.itemized_bill = params[:itemized_bill]
		wkaccountproject.billing_type = params[:billing_type]
		
		if !wkaccountproject.save()			
			errorMsg = wkaccountproject.errors.full_messages.join('\n')
		end
		
		milestonelength = params[:mtotalrow].to_i
		unless wkaccountproject.id.blank?
			
			unless params[:applytax].to_i == 0 
				taxId = params[:tax_id]	
				WkAccProjectTax.where(:account_project_id => wkaccountproject.id).where.not(:tax_id => taxId).delete_all()
				unless taxId.blank?
					taxId.collect{ |id| 
						istaxid = WkAccProjectTax.where("account_project_id = ? and tax_id = ? ", wkaccountproject.id, id).count
						unless istaxid > 0
							wkaccprojecttax = WkAccProjectTax.new
							wkaccprojecttax.account_project_id = wkaccountproject.id
							wkaccprojecttax.tax_id = id
							if !wkaccprojecttax.save()
								errorMsg = wkaccountproject.errors.full_messages.join('\n')
							end
						end						
					}
				end
				
			end
			
			for i in 1..milestonelength
				if params["milestone_id#{i}"].blank? #&& !params["milestone#{i}"].blank?
					wkbillingschedule = WkBillingSchedule.new
				else # if !params["milestone_id#{i}"].blank?
					wkbillingschedule = WkBillingSchedule.find(params["milestone_id#{i}"].to_i)
					arrId << params["milestone_id#{i}"].to_i
				end
				wkbillingschedule.milestone = params["milestone#{i}"]
				wkbillingschedule.bill_date = params["billdate#{i}"]#.strftime('%F')
				wkbillingschedule.amount = params["amount#{i}"]
				wkbillingschedule.currency = "$"
				wkbillingschedule.invoice_id = ""
				wkbillingschedule.account_project_id = wkaccountproject.id
				if !wkbillingschedule.save()			
					errorMsg =  wkbillingschedule.errors.full_messages.join('\n')
				end
			
			end
			WkBillingSchedule.where(:account_project_id => wkaccountproject.id).where.not(:id => arrId).delete_all()
		end
				
		if errorMsg.nil? 
			redirect_to :action => 'index' , :tab => 'wkaccountproject'
			flash[:notice] = l(:notice_successful_update)
	    else
			flash[:error] = errorMsg
			redirect_to :action => 'edit', :acc_project_id => params[:accountProjectId]
	    end
	end
	
	def destroy
	end	
  
    def set_filter_session
        if params[:searchlist].blank? && session[:accountproject].nil?
			session[:accountproject] = {:account_id => params[:account_id], :project_id => params[:project_id]}
		elsif params[:searchlist] =='accountproject'
			session[:accountproject][:account_id] = params[:account_id]
			session[:accountproject][:project_id] = params[:project_id]
		end
		
   end
   
    def setLimitAndOffset		
		if api_request?
			@offset, @limit = api_offset_and_limit
			if !params[:limit].blank?
				@limit = params[:limit]
			end
			if !params[:offset].blank?
				@offset = params[:offset]
			end
		else
			@entry_pages = Paginator.new @entry_count, per_page_option, params['page']
			@limit = @entry_pages.per_page
			@offset = @entry_pages.offset
		end	
	end
	
	def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		@accountproject = entries.limit(@limit).offset(@offset)
	end

end
