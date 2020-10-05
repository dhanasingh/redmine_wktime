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

class WkleadController < WkcrmController
  unloadable
  include WktimeHelper
  include WkleadHelper
  accept_api_auth :index, :edit, :getuserGrp, :update

	def index
		sort_init 'updated_at', 'desc'
		
		sort_update 'lead_name' => "CONCAT(C.first_name, C.last_name)",
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
			LEFT JOIN wk_locations AS L on C.location_id = L.id")

		if !leadName.blank? && !status.blank?
		    entries = entries.where(:status => status).joins(:contact).where("LOWER(C.first_name) like LOWER(?) OR LOWER(C.last_name) like LOWER(?)", "%#{leadName}%", "%#{leadName}%")
		elsif !leadName.blank? && status.blank?
			entries = entries.where.not(:status => 'C').joins(:contact).where("LOWER(C.first_name) like LOWER(?) OR LOWER(C.last_name) like LOWER(?)", "%#{leadName}%", "%#{leadName}%")
		elsif leadName.blank? && !status.blank?
			entries = entries.where(:status => status).joins(:contact).where("LOWER(C.first_name) like LOWER(?) OR LOWER(C.last_name) like LOWER(?)", "%#{leadName}%", "%#{leadName}%")
		else
			entries = entries.joins(:contact).where.not(:status => 'C')
		end

		if (!locationId.blank? || !location.blank?) && locationId != "0"
			location_id = !locationId.blank? ? locationId.to_i : location.id.to_i
			entries = entries.where("C.location_id = ? ", location_id)
		end
		formPagination(entries.reorder(sort_clause))
		respond_to do |format|
			format.html {        
			  render :layout => !request.xhr?
			}
			format.api
		end
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
		wkLead = update_without_redirect
		respond_to do |format|
			format.html {
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
	}
	format.api{
		errorMsg = @wkContact.errors.full_messages.join("<br>")
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
		WkLead.find(params[:lead_id].to_i).destroy
		flash[:notice] = l(:notice_successful_delete)
		redirect_back_or_default :action => 'index', :tab => params[:tab]
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
   
	def getContactType
		'C'
	end
	
	def getAccountLbl
		l(:label_account)
	end

	def set_filter_session
		if params[:searchlist] == controller_name || api_request?
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

	def getuserGrp
		users = groupOfUsers
		grpUser = []
		grpUser = users.map { |usr| { value: usr[1], label: usr[0] }}
		render json: grpUser
	end

end
