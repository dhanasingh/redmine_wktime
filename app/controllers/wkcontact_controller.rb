# ERPmine - ERP for service industry
# Copyright (C) 2011-2020  Adhi software pvt ltd
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class WkcontactController < WkcrmController
  unloadable
  include WkaccountprojectHelper

	def index
		sort_init 'updated_at', 'desc'

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
				wkcontact = wkcontact.joins("LEFT OUTER JOIN wk_leads ON wk_crm_contacts.id = wk_leads.contact_id").where(:contact_type => getContactType, wk_leads: { status: ['C', nil] }).where.not(:account_id => nil).where("LOWER(wk_crm_contacts.first_name) like LOWER(?) OR LOWER(wk_crm_contacts.last_name) like LOWER(?)", "%#{contactName}%", "%#{contactName}%")
			else
				wkcontact = wkcontact.joins("LEFT OUTER JOIN wk_leads ON wk_crm_contacts.id = wk_leads.contact_id").where(:contact_type => getContactType, wk_leads: { status: ['C', nil] }).where(:account_id => accountId).where("LOWER(wk_crm_contacts.first_name) like LOWER(?) OR LOWER(wk_crm_contacts.last_name) like LOWER(?)", "%#{contactName}%", "%#{contactName}%")
			end
		
		elsif contactName.blank? &&  !accountId.blank?
			if accountId == 'AA'
				wkcontact = wkcontact.joins("LEFT OUTER JOIN wk_leads ON wk_crm_contacts.id = wk_leads.contact_id").where(:contact_type => getContactType, wk_leads: { status: ['C', nil] }).where.not(:account_id => nil)
			else
				wkcontact = wkcontact.joins("LEFT OUTER JOIN wk_leads ON wk_crm_contacts.id = wk_leads.contact_id").where(:contact_type => getContactType, wk_leads: { status: ['C', nil] }).where(:account_id => accountId)
			end
		
		elsif !contactName.blank? &&  accountId.blank?
			wkcontact = wkcontact.joins("LEFT OUTER JOIN wk_leads ON wk_crm_contacts.id = wk_leads.contact_id").where(:contact_type => getContactType, wk_leads: { status: ['C', nil] }).where(:account_id => nil).where("LOWER(wk_crm_contacts.first_name) like LOWER(?) OR LOWER(wk_crm_contacts.last_name) like LOWER(?)", "%#{contactName}%", "%#{contactName}%")
		else
			wkcontact = wkcontact.joins("LEFT OUTER JOIN wk_leads ON wk_crm_contacts.id = wk_leads.contact_id").where(:contact_type => getContactType, wk_leads: { status: ['C', nil] }).where(:account_id => nil)
		end
		if (!locationId.blank? || !location.blank?) && locationId != "0"
			location_id = !locationId.blank? ? locationId.to_i : location.id.to_i
			wkcontact = wkcontact.where("wk_crm_contacts.location_id = ? ", location_id)
		end
		formPagination(wkcontact.reorder(sort_clause))
		respond_to do |format|
			format.html {        
			  render :layout => !request.xhr?
			}
			format.api
		end
	end

	def edit
		@conEditEntry = nil		
		unless params[:contact_id].blank?
			set_filter_session
			@accountproject = formPagination(accountProjctList)
			@conEditEntry = WkCrmContact.find(params[:contact_id])
		end

		respond_to do |format|
			format.html {        
			  render :layout => !request.xhr?
			}
			format.api
		end
	end
	
	def update
		wkContact = contactSave
		errorMsg = wkContact.errors.full_messages.join("<br>")
		respond_to do |format|
			format.html {
				if errorMsg.blank?
					redirect_to :controller => controller_name,:action => 'index' , :tab => controller_name
						flash[:notice] = l(:notice_successful_update)
				else
					flash[:error] = errorMsg
						redirect_to :controller => controller_name,:action => 'edit'
				end
			}
			format.api{
				if errorMsg.blank?
					render :plain => errorMsg, :layout => nil
				else			
					@error_messages = errorMsg.split('\n')	
					render :template => 'common/error_messages.api', :status => :unprocessable_entity, :layout => nil
				end
			}
		end
	end
	
	def destroy
	    contact = WkCrmContact.find(params[:contact_id].to_i)
		if contact.destroy
			flash[:notice] = l(:notice_successful_delete)
			delete_documents(params[:contact_id])
		else
			flash[:error] = contact.errors.full_messages.join("<br>")
		end
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end
	
	def set_filter_session
		if params[:searchlist] == controller_name || api_request?
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
		@contact = entries.limit(@limit).offset(@offset)
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