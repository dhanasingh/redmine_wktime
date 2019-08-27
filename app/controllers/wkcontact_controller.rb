class WkcontactController < WkcrmController
  unloadable
  include WkaccountprojectHelper

	def index
		sort_init 'id', 'asc'

		sort_update 'name' => "CONCAT(wk_crm_contacts.first_name, wk_crm_contacts.last_name)",
					'acc_name' => "A.name",
					'location_name' => "L.name",
					'title' => "#{WkCrmContact.table_name}.title",
					'assigned_user_id' => "CONCAT(U.firstname, U.lastname)",
					'updated_at' => "#{WkCrmContact.table_name}.updated_at"

		set_filter_session
		contactName = session[controller_name].try(:[], :contactname)
		accountId =  session[controller_name].try(:[], :account_id)
		locationId = session[controller_name].try(:[], :location_id)

		wkcontact = WkCrmContact.joins("LEFT JOIN wk_accounts AS A ON wk_crm_contacts.account_id = A.id
			LEFT JOIN wk_locations AS L on wk_crm_contacts.location_id = L.id
			LEFT JOIN users AS U on wk_crm_contacts.assigned_user_id = U.id")

		location = WkLocation.where(:is_default => 'true').first
		if !contactName.blank? &&  !accountId.blank?
			if accountId == 'AA'
				wkcontact = wkcontact.includes(:lead).where(:contact_type => getContactType, wk_leads: { status: ['C', nil] }).where.not(:account_id => nil).where("LOWER(wk_crm_contacts.first_name) like LOWER(?) OR LOWER(wk_crm_contacts.last_name) like LOWER(?)", "%#{contactName}%", "%#{contactName}%")
			else
				wkcontact = wkcontact.includes(:lead).where(:contact_type => getContactType, wk_leads: { status: ['C', nil] }).where(:account_id => accountId).where("LOWER(wk_crm_contacts.first_name) like LOWER(?) OR LOWER(wk_crm_contacts.last_name) like LOWER(?)", "%#{contactName}%", "%#{contactName}%")
			end
		
		elsif contactName.blank? &&  !accountId.blank?
			if accountId == 'AA'
				wkcontact = wkcontact.includes(:lead).where(:contact_type => getContactType, wk_leads: { status: ['C', nil] }).where.not(:account_id => nil)
			else
				wkcontact = wkcontact.includes(:lead).where(:contact_type => getContactType, wk_leads: { status: ['C', nil] }).where(:account_id => accountId)
			end
		
		elsif !contactName.blank? &&  accountId.blank?
			wkcontact = wkcontact.includes(:lead).where(:contact_type => getContactType, wk_leads: { status: ['C', nil] }).where(:account_id => nil).where("LOWER(wk_crm_contacts.first_name) like LOWER(?) OR LOWER(wk_crm_contacts.last_name) like LOWER(?)", "%#{contactName}%", "%#{contactName}%")
		else
			wkcontact = wkcontact.includes(:lead).where(:contact_type => getContactType, wk_leads: { status: ['C', nil] }).where(:account_id => nil)
		end
		if (!locationId.blank? || !location.blank?) && locationId != "0"
			location_id = !locationId.blank? ? locationId.to_i : location.id.to_i
			wkcontact = wkcontact.where("wk_crm_contacts.location_id = ? ", location_id)
		end
		formPagination(wkcontact.reorder(sort_clause))
	end

	def edit
		@conEditEntry = nil		
		unless params[:contact_id].blank?
			set_filter_session
			@accountproject = formPagination(accountProjctList)
			@conEditEntry = WkCrmContact.where(:id => params[:contact_id].to_i)
		end
	end
	
	def update
		errorMsg = nil
		if params[:contact_id].blank?
		    wkContact = WkCrmContact.new 
	    else
		    wkContact = WkCrmContact.find(params[:contact_id].to_i)
	    end
		# For Contact table
		wkContact.assigned_user_id = params[:assigned_user_id]
		wkContact.first_name = params[:first_name]
		wkContact.last_name = params[:last_name]
		wkContact.address_id = params[:address_id]
		wkContact.title = params[:contact_title]
		wkContact.description = params[:description]
		wkContact.department = params[:department]
		wkContact.salutation = params[:salutation]
		wkContact.account_id = nil #params[:account_id]
		wkContact.contact_id = nil
		wkContact.account_id = params[:related_parent] if params[:related_to] == "WkAccount"
		wkContact.contact_id = params[:related_parent] if params[:related_to] == "WkCrmContact"
		wkContact.relationship_id = params[:relationship_id]
		wkContact.location_id = params[:location_id] if params[:location_id] != "0"
		wkContact.contact_type = getContactType
		wkContact.created_by_user_id = User.current.id if wkContact.new_record?
		wkContact.updated_by_user_id = User.current.id
		addrId = updateAddress
		unless addrId.blank?
			wkContact.address_id = addrId
		end
		unless wkContact.valid?		
			errorMsg = wkContact.errors.full_messages.join("<br>")	
		else
			wkContact.save
		end
		
		if errorMsg.blank?
			redirect_to :controller => controller_name,:action => 'index' , :tab => controller_name
		    flash[:notice] = l(:notice_successful_update)
		else
			flash[:error] = errorMsg
		    redirect_to :controller => controller_name,:action => 'edit'
		end
		
	end
	
	def destroy
	    contact = WkCrmContact.find(params[:contact_id].to_i)
		if contact.destroy
			flash[:notice] = l(:notice_successful_delete)
		else
			flash[:error] = contact.errors.full_messages.join("<br>")
		end
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end
	
	def set_filter_session
		if params[:searchlist] == controller_name
			session[controller_name] = Hash.new if session[controller_name].nil?
			filters = [:contactname, :account_id, :location_id]
			filters.each do |param|
				if params[param].blank? && session[controller_name].try(:[], param).present?
					session[controller_name].delete(param)
				elsif params[param].present?
					session[controller_name][param] = params[param]
				end
			end
		end
    end
	
	def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		@contact = entries.order(updated_at: :desc).limit(@limit).offset(@offset)
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
	
	def getAccountLbl
		l(:label_account)
	end
	
	def contactLbl
		l(:label_contact_plural)
	end

end