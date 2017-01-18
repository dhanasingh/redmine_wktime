class WkleadController < ApplicationController
  unloadable
  include WktimeHelper


	def index
		@leadEntries = WkLead.all
		if params[:lead_name].blank?
		   entries = WkLead.all
		else
			entries = WkLead.joins(:contacts).where("LOWER(wk_crm_contacts.first_name) like LOWER(?) OR LOWER(wk_crm_contacts.last_name) like LOWER(?)", "%#{params[:lead_name]}%", "%#{params[:lead_name]}%")
		end
		formPagination(entries)
	end
	  
	def show
		@lead = nil
		@lead = WkLead.find(params[:lead_id]) unless params[:lead_id].blank?
		@lead
	end
	  
	def edit
		@lead = nil
		@lead = WkLead.find(params[:lead_id]) unless params[:lead_id].blank?
		@lead
	end
	  
	def update
		errorMsg = nil
		wkAddress = nil
	    if params[:address_id].blank? || params[:address_id].to_i == 0
		    wkAddress = WkAddress.new 
	    else
		    wkAddress = WkAddress.find(params[:address_id].to_i)
	    end
		# For Address table
		wkAddress.address1 = params[:address1]
		wkAddress.address2 = params[:address2]
		wkAddress.work_phone = params[:work_phone]
		wkAddress.city = params[:city]
		wkAddress.state = params[:state]
		wkAddress.pin = params[:pin]
		wkAddress.country = params[:country]
		wkAddress.fax = params[:fax]
		wkAddress.mobile = params[:mobile]
		wkAddress.email = params[:email]
		wkAddress.website = params[:website]
		wkAddress.department = params[:department]
		
		if params[:account_id].blank? || params[:account_id].to_i == 0
			wkaccount = WkAccount.new
		else
		    wkaccount = WkAccount.find(params[:account_id].to_i)
		end
		# For Account table
		wkaccount.name = params[:name]
		
		if params[:lead_id].blank? || params[:lead_id].to_i == 0
			wkLead = WkLead.new
			wkContact = WkCrmContact.new
		else
		    wkLead = WkLead.find(params[:lead_id].to_i)
			wkContact = wkLead.contacts
		end
		# For Lead table
		wkLead.status = params[:status]
		wkLead.opportunity_amount = params[:opportunity_amount]
		wkLead.lead_source_id = params[:lead_source_id]
		wkLead.referred_by = params[:referred_by]
		wkLead.created_by_user_id = User.current.id if wkLead.new_record?
		wkLead.updated_by_user_id = User.current.id
		
		# For Contact table
		wkContact.assigned_user_id = params[:assigned_user_id]
		wkContact.first_name = params[:first_name]
		wkContact.last_name = params[:last_name]
		#wkContact.address_id = params[:address_id]
		wkContact.title = params[:title]
		wkContact.department = params[:department]
		wkContact.salutation = params[:salutation]
		wkContact.contact_type = params[:contact_type]
		wkContact.created_by_user_id = User.current.id if wkContact.new_record?
		wkContact.updated_by_user_id = User.current.id
		if wkContact.valid?
			if wkAddress.valid?
				wkAddress.save
				wkLead.address_id = wkAddress.id
				wkContact.address_id = wkAddress.id
				wkaccount.address_id = wkAddress.id
			end
			
			if wkaccount.valid?
				wkaccount.account_type = 'L'
				wkaccount.save
				wkLead.account_id = wkaccount.id
			end
			
			if wkLead.save
				wkContact.parent_id = wkLead.id
				wkContact.parent_type = wkLead.class.name
			end
			wkContact.save
		    redirect_to :controller => 'wklead',:action => 'index' , :tab => 'wklead'
		    flash[:notice] = l(:notice_successful_update)
		else
			flash[:error] = wkContact.errors.full_messages.join("<br>")
		    redirect_to :controller => 'wklead',:action => 'edit', :lead_id => wkLead.id
		end
	end
	
	def formPagination(entries)
		@entry_count = entries.count
		setLimitAndOffset()
		@leadEntries = entries.limit(@limit).offset(@offset)
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

end
