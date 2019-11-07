class WkleadController < WkcrmController
  unloadable
  include WktimeHelper
  include WkcustomfieldsHelper
  helper_method :sort_column, :sort_direction

	def index
		@leadEntries = WkLead.all
		if !params[:lead_name].blank? && !params[:status].blank?
			entries = WkLead.where(:status => params[:status]).joins(:contact).where("LOWER(wk_crm_contacts.first_name) like LOWER(?) OR LOWER(wk_crm_contacts.last_name) like LOWER(?)", "%#{params[:lead_name]}%", "%#{params[:lead_name]}%")
		elsif !params[:lead_name].blank? && params[:status].blank?
			entries = WkLead.where.not(:status => 'C').joins(:contact).where("LOWER(wk_crm_contacts.first_name) like LOWER(?) OR LOWER(wk_crm_contacts.last_name) like LOWER(?)", "%#{params[:lead_name]}%", "%#{params[:lead_name]}%")
		elsif params[:lead_name].blank? && !params[:status].blank?
			entries = WkLead.where(:status => params[:status]).joins(:contact).where("LOWER(wk_crm_contacts.first_name) like LOWER(?) OR LOWER(wk_crm_contacts.last_name) like LOWER(?)", "%#{params[:lead_name]}%", "%#{params[:lead_name]}%")
		else
			entries = WkLead.joins(:contact).where.not(:status => 'C')
		end

		if !params[:location_id].blank?
			entries = entries.where("wk_crm_contacts.location_id = ? ", params[:location_id].to_i)
		end
		if !params[:address].blank?
			entries = entries.joins(contact: [:address]).where("LOWER(wk_addresses.address1) LIKE ? OR LOWER(wk_addresses.address2) LIKE ?", "%#{params[:address].downcase}%", "%#{params[:address].downcase}%")
		end
		if !params[:city].blank?
			entries = entries.joins(contact: [:address]).where("LOWER(wk_addresses.city) LIKE ?", "%#{params[:city].downcase}%")
		end
		if !params[:phone].blank?
			 entries = entries.joins(contact: [:address]).where("LOWER(wk_addresses.work_phone) LIKE ? OR LOWER(wk_addresses.home_phone) LIKE ? OR LOWER(wk_addresses.mobile) LIKE ?", "%#{params[:phone].downcase}%", "%#{params[:phone].downcase}%", "%#{params[:phone].downcase}%")
		end
		@entryTab = entries
		formPagination(entries)
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
    @wcf = nil
    @relationDict = nil
    @sort_by = {}
    @filter = {}
    unless params[:lead_id].blank?
  		@lead = WkLead.find(params[:lead_id])
      @wcf = WkCustomField.where(custom_fields_id: CustomField.where(field_format: "wk_lead"))
      @wcf.map(&:display_as).uniq.each do |section|
        custom_value_entries = @lead.custom_values.where(custom_field_id: WkCustomField.where(display_as: section).map(&:custom_fields_id).uniq)
        sortCustomValuesBy = params["sort_#{section}_by"].nil? ? 'date' : params["sort_#{section}_by"]
        @filter[section]= setCustomValuesFilter(params, section).clone
        @sort_by[section] = sortCustomValuesBy
        customValuesPagination(custom_value_entries, section, sortCustomValuesBy, @filter[section])
      end
      @filter[:current_section] = params[:current_section] unless params[:current_section].nil?
      @relationDict = getRelationDict(@lead)
  	end
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
		wkaccount.location_id = params[:location_id]
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
		wkContact.title = params[:title]
		wkContact.description = params[:description]
		wkContact.department = params[:department]
		wkContact.salutation = params[:salutation]
		wkContact.location_id = params[:location_id]
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
			isConvert = wkLead.status == 'C' && wkLead.status_changed?
			wkLead.save
			if params[:wklead_save_convert] || isConvert
				redirect_to :action => 'convert', :lead_id => wkLead.id
			else
				redirect_to :controller => 'wklead',:action => 'index' , :tab => 'wklead'
				flash[:notice] = l(:notice_successful_update)
			end
		else
			flash[:error] = wkContact.errors.full_messages.join("<br>")
		    redirect_to :controller => 'wklead',:action => 'edit', :lead_id => wkLead.id
		end
	end

	def destroy
		lead = WkLead.find(params[:lead_id].to_i)
		JournalDetail.where(property: "cf", prop_key: CustomField.where(field_format: "wk_lead").to_s.to_i, old_value: lead.id).update_all(old_value: "deleted")
		JournalDetail.where(property: "cf", prop_key: CustomField.where(field_format: "wk_lead").to_s.to_i, value: lead.id).update_all(value: "deleted")
		lead.destroy
		flash[:notice] = l(:notice_successful_delete)
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end

	def formPagination(entries)
		@entry_count = entries.count
		setLimitAndOffset()
		if(sort_column == "last_name")
			@leadEntries = entries.joins(contact: [:address]).joins("LEFT JOIN wk_accounts ON wk_accounts.id = wk_leads.account_id").joins("LEFT JOIN wk_locations ON wk_locations.id = wk_accounts.location_id").joins("LEFT JOIN users ON users.id = wk_leads.updated_by_user_id").order(sort_column  + " " + sort_direction + ", first_name asc").limit(@limit).offset(@offset)
		else
			@leadEntries = entries.joins(contact: [:address]).joins("LEFT JOIN wk_accounts ON wk_accounts.id = wk_leads.account_id").joins("LEFT JOIN wk_locations ON wk_locations.id = wk_accounts.location_id").joins("LEFT JOIN users ON users.id = wk_leads.updated_by_user_id").order(sort_column  + " " + sort_direction + ", last_name asc, first_name asc").limit(@limit).offset(@offset)
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

	def getContactType
		'C'
	end

	def getAccountLbl
		l(:label_account)
	end

	private

	def sort_column
		allColumns = [WkLead, WkAddress, WkCrmContact].flat_map(&:column_names).uniq
		allColumns.push("wk_accounts.name", "wk_addresses.work_phone", "wk_leads.updated_at", "wk_locations.name", "users.lastname")
		allColumns.include?(params[:sort]) ? params[:sort] : "last_name"
	end

	def sort_direction
		%w[asc desc].include?(params[:direction]) ? params[:direction] : "asc"
	end

end
