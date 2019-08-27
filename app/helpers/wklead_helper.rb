module WkleadHelper
include WktimeHelper
include WkcrmHelper
include WkcrmactivityHelper
include WkinvoiceHelper
include WkcrmenumerationHelper

	def getLeadStatusArr
		[
			[l(:label_new),'N'],
			[l(:label_assigned),'A'], 
			[l(:label_in_process),'IP'],
			[l(:label_converted),'C'],
			[l(:label_recycled),'RC'],
			[l(:label_dead),'D']
		]
	end
	
	def getFormComponent(fieldName, fieldValue, compSize, isShow)
		unless isShow
			text_field_tag(fieldName, fieldValue, :size => compSize)
		else
			fieldValue
		end
	end

	def update_without_redirect

		if params[:account_id].blank? || params[:account_id].to_i == 0
			wkaccount = WkAccount.new
		else
		    wkaccount = WkAccount.find(params[:account_id].to_i)
		end
		# For Account table
		wkaccount.name = params[:account_name]
		wkaccount.description = params[:description]
		wkaccount.location_id = params[:location_id] if params[:location_id] != "0"
		if params[:lead_id].blank? || params[:lead_id].to_i == 0
			wkLead = WkLead.new
			wkContact = WkCrmContact.new
		else
		    wkLead = WkLead.find(params[:lead_id].to_i)
			wkContact = wkLead.contact
		end
		# For Lead table
		wkLead.status = params[:status].blank? ? 'N' : params[:status]
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
		wkContact.location_id = params[:location_id] if params[:location_id] != "0"
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
			@isConvert = wkLead.status == 'C' && wkLead.status_changed?
			wkLead.save
		end
		@wkContact = wkContact
		wkLead
	end
end
