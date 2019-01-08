class WkcrmController < WkbaseController
  unloadable
  before_filter :require_login
  before_filter :check_perm_and_redirect, :only => [:index, :edit, :update]
  before_filter :check_crm_admin_and_redirect, :only => [:destroy]
  include WkcrmHelper
  
	def index
	end 
	
	def getActRelatedIds
		relatedArr = ""	
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
		
		if !relatedId.blank?
			relatedId.each do | entry|	
				if params[:related_type] == "WkLead"
					relatedArr <<  entry.id.to_s() + ',' + entry.contact.name  + "\n" 
				elsif params[:related_type].to_s == "WkCrmContact"
					relatedArr <<  entry.id.to_s() + ',' + entry.name  + "\n"
				else
					relatedArr <<  entry.id.to_s() + ',' + entry.name  + "\n" 
				end
			end
		end
		
		respond_to do |format|
			format.text  { render :text => relatedArr }
		end
    end
	
	def check_perm_and_redirect
		unless check_permission
			render_403
			return false
		end
	end
	
	def check_crm_admin_and_redirect
	  unless isModuleAdmin('wktime_crm_admin') 
	    render_403
	    return false
	  end
    end

	def check_permission
		ret = false
		return isModuleAdmin('wktime_crm_group') || isModuleAdmin('wktime_crm_admin') 
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
		isModuleAdmin('wktime_crm_admin')
	end
	
	def additionalContactType
		true
	end

end
