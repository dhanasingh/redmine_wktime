class WkleadController < WkcrmController
  unloadable
  include WktimeHelper
  include WkleadHelper

	def index
		sort_init 'id', 'asc'
		
		sort_update 'lead_name' => "CONCAT(wk_crm_contacts.first_name, wk_crm_contacts.last_name)",
			'status' => "#{WkLead.table_name}.status",
			'location_name' => "L.name",
			'acc_name' => "A.name",
			'created_by_user_id' => "CONCAT(U.firstname, U.lastname)",
			'updated_at' => "#{WkLead.table_name}.updated_at"

		set_filter_session
		leadName = session[controller_name].try(:[], :lead_name)
		status = session[controller_name].try(:[], :status)
		locationId = session[controller_name].try(:[], :location_id)
		location = WkLocation.where(:is_default => 'true').first
		
		entries = WkLead.joins("LEFT JOIN users AS U ON wk_leads.created_by_user_id = U.id
			LEFT JOIN wk_accounts AS A on wk_leads.account_id = A.id
			LEFT JOIN wk_crm_contacts AS C on wk_leads.contact_id = C.id
			LEFT JOIN wk_locations AS L on wk_crm_contacts.location_id = L.id")

		if !leadName.blank? && !status.blank?
		    entries = entries.where(:status => status).joins(:contact).where("LOWER(wk_crm_contacts.first_name) like LOWER(?) OR LOWER(wk_crm_contacts.last_name) like LOWER(?)", "%#{leadName}%", "%#{leadName}%")
		elsif !leadName.blank? && status.blank?
			entries = entries.where.not(:status => 'C').joins(:contact).where("LOWER(wk_crm_contacts.first_name) like LOWER(?) OR LOWER(wk_crm_contacts.last_name) like LOWER(?)", "%#{leadName}%", "%#{leadName}%")
		elsif leadName.blank? && !status.blank?
			entries = entries.where(:status => status).joins(:contact).where("LOWER(wk_crm_contacts.first_name) like LOWER(?) OR LOWER(wk_crm_contacts.last_name) like LOWER(?)", "%#{leadName}%", "%#{leadName}%")
		else
			entries = entries.joins(:contact).where.not(:status => 'C')
		end

		if (!locationId.blank? || !location.blank?) && locationId != "0"
			location_id = !locationId.blank? ? locationId.to_i : location.id.to_i
			entries = entries.where("wk_crm_contacts.location_id = ? ", location_id)
		end
		formPagination(entries.reorder(sort_clause))
	end
	  
	def show
		@lead = nil
		@lead = WkLead.find(params[:lead_id]) unless params[:lead_id].blank?
		@lead
	end
	
	def convert
		@lead = nil
		errorMsg = nil
		@lead = WkLead.find(params[:lead_id]) unless params[:lead_id].blank?
		@lead.status = 'C'
		@lead.updated_by_user_id = User.current.id
		#@lead.save
		@contact = @lead.contact
		@account = @lead.account
		hookcontactType = call_hook(:controller_convert_contact, {:params => params, :leadObj => @lead, :contactObj => @contact})
		contactType = hookcontactType.blank? ? getContactType : hookcontactType[0][0]
		@contact.contact_type = contactType
		errorMsg = call_hook(:controller_updated_contact, {:params => params, :leadObj => @lead, :contactObj => @contact})
		if errorMsg[0].blank?
			@lead.save
			convertToAccount unless @account.blank?
			convertToContact #(contactType)
		end
		
		
		unless @account.blank?
			flash[:notice] = l(:notice_successful_convert)
			redirect_to :controller => 'wkcrmaccount',:action => 'edit', :account_id => @account.id
		else
			controllerName = hookcontactType.blank? ? 'wkcrmcontact' : hookcontactType[0][1]
			if errorMsg[0].blank?
				flash[:notice] = l(:notice_successful_convert)
			else
				flash[:error] = errorMsg[0]
				controllerName = 'wklead'
			end
			
		    redirect_to :controller => controllerName, :action => 'edit', :contact_id => @contact.id, :lead_id => @lead.id
		end
	end
	
	def convertToAccount
		@account.account_type = 'A'
		@account.updated_by_user_id = User.current.id
		address = nil
		unless @contact.address.blank?
			address = copyAddress(@contact.address) 
			@account.address_id = address.id
		end
		@account.save
	end
	
	def convertToContact #(contactType)
		@contact.updated_by_user_id = User.current.id		
		#@contact.contact_type = contactType
		unless @account.blank?
			@contact.account_id = @account.id
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

		wkLead = update_without_redirect
		if @wkContact.valid?
			if params[:wklead_save_convert] || @isConvert
				redirect_to :action => 'convert', :lead_id => wkLead.id
			else
				redirect_to :controller => 'wklead',:action => 'index' , :tab => 'wklead'
				flash[:notice] = l(:notice_successful_update)
			end
		else
			flash[:error] = @wkContact.errors.full_messages.join("<br>")
		    redirect_to :controller => 'wklead',:action => 'edit', :lead_id => wkLead.id
		end 
	end
  
    def destroy
		WkLead.find(params[:lead_id].to_i).destroy
		flash[:notice] = l(:notice_successful_delete)
		redirect_back_or_default :action => 'index', :tab => params[:tab]
    end
	
	def formPagination(entries)
		@entry_count = entries.count
		setLimitAndOffset()
		@leadEntries = entries.order(updated_at: :desc).limit(@limit).offset(@offset)
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
   
	def getContactType
		'C'
	end
	
	def getAccountLbl
		l(:label_account)
	end

	def set_filter_session
		if params[:searchlist] == controller_name
			session[controller_name] = Hash.new if session[controller_name].nil?
			filters = [:lead_name, :status, :location_id]
			filters.each do |param|
				if params[param].blank? && session[controller_name].try(:[], param).present?
					session[controller_name].delete(param)
				elsif params[param].present?
					session[controller_name][param] = params[param]
				end
			end
		end
    end

end
