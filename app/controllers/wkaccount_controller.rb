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
		else 
          @accountEntry = @accountEntry
		  
	    end
    end	
	
	def update
	    if params[:address_id].blank? || params[:address_id].to_i == 0
		    wkaddress = WkAddress.new 
	    else
		    wkaddress = WkAddress.find(params[:address_id].to_i)
	    end
		wkaddress.address1 = params[:address1]
		wkaddress.address2 = params[:address2]
		wkaddress.work_phone = params[:work_phone]
		wkaddress.home_phone = params[:home_phone]
		wkaddress.city = params[:city]
		wkaddress.state = params[:state]
		wkaddress.pin = params[:pin]
		wkaddress.mobile = params[:mobile]
		wkaddress.email = params[:email]
		wkaddress.country = params[:country]
		wkaddress.fax = params[:fax]
		wkaddress.save()
		address_id = wkaddress.id
		if params[:account_id].blank? || params[:account_id].to_i == 0
			wkaccount = WkAccount.new
		else
		    wkaccount = WkAccount.find(params[:account_id].to_i)
		end
		wkaccount.address_id = address_id
		wkaccount.name = params[:name]
		wkaccount.account_type = params[:account_type]
		wkaccount.save()
		if wkaccount.save()
		    redirect_to :controller => 'wkaccount',:action => 'index' , :tab => 'account'
		    flash[:notice] = l(:notice_successful_update)
		else
		    redirect_to :controller => 'wkaccount',:action => 'edit' , :tab => 'account'
		    flash[:error] = wkaccount.errors.full_messages.join('\n')
		end
	end	
end
