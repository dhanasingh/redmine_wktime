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

class WkaccountController < WkcrmController

	include WkaccountprojectHelper
    before_action :require_login

	def index
		sort_init 'updated_at', 'desc'

		sort_update 'acc_name' => "#{WkAccount.table_name}.name",
					'country' => "A.country",
					'city' => "A.city",
					'location_name' => "L.name",
					'updated_at' => "#{WkAccount.table_name}.updated_at"
					
		set_filter_session
		locationId = session[controller_name].try(:[], :location_id)
		accName = session[controller_name].try(:[], :accountname)
		@account_entries = nil
		location = WkLocation.where(:is_default => 'true').first

		entries = WkAccount.joins("LEFT JOIN wk_locations AS L ON wk_accounts.location_id = L.id
			LEFT JOIN wk_addresses AS A on wk_accounts.address_id = A.id")

		if accName.blank?
			entries = entries.where(:account_type => getAccountType)
		else
			entries = entries.where(:account_type => getAccountType).where("wk_accounts.name like ?", "%#{accName}%")
		end
		if (!locationId.blank? || !location.blank?) && locationId != "0"
			location_id = !locationId.blank? ? locationId.to_i : location.id.to_i
			entries = entries.where(:location_id => location_id)
		end
		entries = entries.order(:name)
		formPagination(entries.reorder(sort_clause))
		respond_to do |format|
			format.html {        
			  render :layout => !request.xhr?
			}
			format.api
		end
	end
	
	def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		@account_entries = entries.limit(@limit).offset(@offset)
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
   
	def edit
		
	     @accountEntry = nil
		 unless params[:account_id].blank?
			set_filter_session
			@accountproject = formPagination(accountProjctList)
	
		  @accountEntry = WkAccount.find(params[:account_id])
		end
		respond_to do |format|
			format.html {        
			  render :layout => !request.xhr?
			}
			format.api
		end
    end	
	
	def update
		wkaccount = accountSave
		errorMsg = wkaccount.errors.full_messages.join("<br>")
		respond_to do |format|
			format.html {
				if errorMsg.blank?
					redirect_to :controller => controller_name,:action => 'index' , :tab => controller_name 
					flash[:notice] = l(:notice_successful_update)
				else
					flash[:error] = errorMsg
					redirect_to :controller => controller_name, :action => 'edit', :account_id => wkaccount.id
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
		account = WkAccount.find(params[:id].to_i)
		if account.destroy
			flash[:notice] = l(:notice_successful_delete)
			delete_documents(params[:id])
		else
			flash[:error] = account.errors.full_messages.join("<br>")
		end
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end
	
	def getAccountLbl
		l(:label_account)
	end

	def set_filter_session
		if params[:searchlist] == controller_name || api_request?
			session[controller_name] = Hash.new if session[controller_name].nil?
			filters = [:location_id, :accountname]
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
