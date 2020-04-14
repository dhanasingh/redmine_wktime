class WkcrmController < WkbaseController
  unloadable
  before_action :require_login
  before_action :check_perm_and_redirect, :only => [:index, :edit, :update]
  before_action :check_crm_admin_and_redirect, :only => [:destroy]
  include WkcrmHelper
  include WktimeHelper
  accept_api_auth :getActRelatedIds, :getCrmUsers
  
	def index
	end 
	
	def getActRelatedIds
		relatedArr = params[:format] == "json" ? [] : ""	
		relatedId = nil
		
		if params[:related_type] == "WkOpportunity"
			relatedId = WkOpportunity.all.order(:name)
		elsif params[:related_type] == "WkLead"
			relatedId = WkLead.includes(:contact).where.not(:status => 'C').order("wk_crm_contacts.first_name, wk_crm_contacts.last_name")
		elsif params[:related_type] == "WkCrmContact"
			#relatedId = WkCrmContact.includes(:lead).where(wk_leads: { status: ['C', nil] }).where(:contact_type => params[:contact_type]).order(:first_name, :last_name)
			hookType = call_hook(:additional_contact_type)
			if hookType[0].blank? || params[:additionalContactType] == "false"
				relatedId = WkCrmContact.includes(:lead).where(:account_id => nil, :contact_id => nil).where(wk_leads: { status: ['C', nil] }).where(:contact_type => params[:contact_type]).order(:first_name, :last_name)
			else
				relatedId = WkCrmContact.includes(:lead).where(:account_id => nil, :contact_id => nil).where(wk_leads: { status: ['C', nil] }).where("wk_crm_contacts.contact_type = '#{params[:contact_type]}' or wk_crm_contacts.contact_type = '#{hookType[0]}'").order(:first_name, :last_name)
			end
		elsif params[:related_type] != "0"
			relatedId = WkAccount.where(:account_type => params[:account_type]).order(:name)
		end
		
		(relatedId || []).each do | entry|
			if params[:format] == "json"
				relatedArr << { value: entry.id, label: (params[:related_type] == "WkLead" ? entry.contact.name : entry.name) }
			else
				relatedArr << entry.id.to_s() + ',' + (params[:related_type] == "WkLead" ? entry.contact.name : entry.name) + "\n"
			end
		end
		respond_to do |format|
			format.text  { render :plain => relatedArr}
			format.api {render :json => relatedArr}
		end
    end
	
	def check_perm_and_redirect
		unless check_permission
			render_403
			return false
		end
	end
	
	def check_crm_admin_and_redirect
	  unless validateERPPermission("A_CRM_PRVLG") 
	    render_403
	    return false
	  end
    end

	def check_permission
		ret = false
		return validateERPPermission("B_CRM_PRVLG") || validateERPPermission("A_CRM_PRVLG") 
	end
	
	def getContactController
		'wkcrmcontact'
	end
	
	def getAccountType
		'A'
	end
	
	def getContactType
		'C'
	end
	
	def deletePermission
		validateERPPermission("A_CRM_PRVLG")
	end
	
	def additionalContactType
		true
	end

	def getCrmUsers
		users = groupOfUsers
		grpUser = []
		grpUser = users.map { |usr| { value: usr[1], label: usr[0] }}
		render json: grpUser
	end

end
