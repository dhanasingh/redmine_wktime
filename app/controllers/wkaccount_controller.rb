class WkaccountController < WkbillingController

before_filter :require_login

    def index
		@account_entries = nil
		if params[:accountname].blank?
		   entries = WkAccount.all
		else
			entries = WkAccount.where("name like ?", "%#{params[:accountname]}%")
		end
		formPagination(entries)
    end
	
	def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		@account_entries = entries.limit(@limit).offset(@offset)
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
   
   	def edit
	     @accountEntry = nil
		 unless params[:account_id].blank?
		  @accountEntry = WkAccount.find(params[:account_id])
		end
    end	
	
	def update
		errorMsg = nil
		wkaddress = nil
	    if params[:address_id].blank? || params[:address_id].to_i == 0
		    wkaddress = WkAddress.new 
	    else
		    wkaddress = WkAddress.find(params[:address_id].to_i)
	    end
		wkaddress.address1 = params[:address1] unless params[:address1].blank?
		wkaddress.address2 = params[:address2] unless params[:address2].blank?
		wkaddress.work_phone = params[:work_phone] unless params[:work_phone].blank?
		wkaddress.city = params[:city] unless params[:city].blank?
		wkaddress.state = params[:state] unless params[:state].blank?
		wkaddress.pin = params[:pin] unless params[:pin].blank?
		wkaddress.country = params[:country] unless params[:country].blank?
		wkaddress.fax = params[:fax] unless params[:fax].blank?
		unless wkaddress.save() 
			errorMsg = wkaddress.errors.full_messages.join("<br>")
		end
		if params[:account_id].blank? || params[:account_id].to_i == 0
			wkaccount = WkAccount.new
		else
		    wkaccount = WkAccount.find(params[:account_id].to_i)
		end
		wkaccount.address_id =  wkaddress.id
		wkaccount.name = params[:name]
		wkaccount.account_type = 'A'
		wkaccount.account_billing = params[:account_billing].blank? ? 0 : params[:account_billing]
		
		unless wkaccount.save() 		
			errorMsg = errorMsg.blank? ? wkaccount.errors.full_messages.join("<br>") : wkaccount.errors.full_messages.join("<br>") + "<br/>" + errorMsg
		end
		if errorMsg.nil?
		    redirect_to :controller => 'wkaccount',:action => 'index' , :tab => 'wkaccount'
		    flash[:notice] = l(:notice_successful_update)
		else
			flash[:error] = errorMsg #wkaccount.errors.full_messages.join("<br>")
		    redirect_to :controller => 'wkaccount',:action => 'edit', :account_id => wkaccount.id
		end
	end
	
	def destroy
		WkAccount.find(params[:id].to_i).destroy
		flash[:notice] = l(:notice_successful_delete)
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end		
end
