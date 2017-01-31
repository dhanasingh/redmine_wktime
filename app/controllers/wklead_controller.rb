class WkleadController < WkcrmController
  unloadable
  include WktimeHelper


	def index
		@leadEntries = WkLead.all
		if params[:lead_name].blank?
		   entries = WkLead.where.not(:status => 'C')
		else
			entries = WkLead.where.not(:status => 'C').joins(:contact).where("LOWER(wk_crm_contacts.first_name) like LOWER(?) OR LOWER(wk_crm_contacts.last_name) like LOWER(?)", "%#{params[:lead_name]}%", "%#{params[:lead_name]}%")
		end
		formPagination(entries)
	end
	  
	def show
		@lead = nil
		@lead = WkLead.find(params[:lead_id]) unless params[:lead_id].blank?
		@lead
	end
	
	def convert
		@lead = nil
		@lead = WkLead.find(params[:lead_id]) unless params[:lead_id].blank?
		@lead.status = 'C'
		@lead.updated_by_user_id = User.current.id
		@lead.save
		@contact = @lead.contact
		@account = @lead.account
		convertToAccount unless @account.blank?
		convertToContact
		unless @account.blank?
			flash[:notice] = l(:notice_successful_convert)
			redirect_to :controller => 'wkaccount',:action => 'edit', :account_id => @account.id
		else
			flash[:notice] = l(:notice_successful_convert)
		    redirect_to :controller => 'wkcrmcontact',:action => 'edit', :contact_id => @contact.id
		end
	end
	
	def convertToAccount
		@account.account_category = 'A'
		@account.updated_by_user_id = User.current.id
		address = nil
		unless @contact.address.blank?
			address = copyAddress(@contact.address) 
			@account.address_id = address.id
		end
		@account.save
	end
	
	def convertToContact
		#@contact.contact_type = 'C'
		@contact.updated_by_user_id = User.current.id
		unless @account.blank?
			@contact.account_id = @account.id
			#@contact.parent_type = @account.class.name
		end
		@contact.save
	end
	
	def copyAddress(source)
		target = WkAddress.new
		target = source.dup
		target.save
		target
	end
	  
	def edit
		@lead = nil
		@lead = WkLead.find(params[:lead_id]) unless params[:lead_id].blank?
		@lead
	end
	  
	def update		
		if params[:account_id].blank? || params[:account_id].to_i == 0
			wkaccount = WkAccount.new
		else
		    wkaccount = WkAccount.find(params[:account_id].to_i)
		end
		# For Account table
		wkaccount.name = params[:account_name]
		wkaccount.description = params[:description]
		if params[:lead_id].blank? || params[:lead_id].to_i == 0
			wkLead = WkLead.new
			wkContact = WkCrmContact.new
		else
		    wkLead = WkLead.find(params[:lead_id].to_i)
			wkContact = wkLead.contact
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
		wkContact.description = params[:description]
		wkContact.department = params[:department]
		wkContact.salutation = params[:salutation]
		wkContact.created_by_user_id = User.current.id if wkContact.new_record?
		wkContact.updated_by_user_id = User.current.id
		if wkContact.valid?
			addrId = updateAddress
			unless addrId.blank?
				wkContact.address_id = addrId
				wkaccount.address_id = addrId
			end
			
			if wkaccount.valid?
				wkaccount.account_type = 'L'
				wkaccount.save
				wkLead.account_id = wkaccount.id
				wkContact.account_id = wkaccount.id
			end
			
			if wkContact.save
				wkLead.contact_id = wkContact.id
			end
			wkLead.save
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
