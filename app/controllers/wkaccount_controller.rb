# ERPmine - ERP for service industry
# Copyright (C) 2011-2016  Adhi software pvt ltd
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
		sort_init 'id', 'asc'

		sort_update 'acc_name' => "#{WkAccount.table_name}.name",
					'country' => "A.country",
					'city' => "A.city",
					'location_name' => "L.name"
					
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
    end	
	
	def update
		errorMsg = nil
		if params[:account_id].blank? || params[:account_id].to_i == 0
			wkaccount = WkAccount.new
		else
		    wkaccount = WkAccount.find(params[:account_id].to_i)
		end
		wkaccount.name = params[:account_name]
		wkaccount.account_type = getAccountType
		wkaccount.account_category = params[:account_category]
		wkaccount.description = params[:description]
		wkaccount.account_billing = params[:account_billing].blank? ? 0 : params[:account_billing]
		wkaccount.location_id = params[:location_id] if params[:location_id] != "0"
		unless wkaccount.valid? 		
			errorMsg = errorMsg.blank? ? wkaccount.errors.full_messages.join("<br>") : wkaccount.errors.full_messages.join("<br>") + "<br/>" + errorMsg
		end
		if errorMsg.nil?
			addrId = updateAddress
			unless addrId.blank?
				wkaccount.address_id = addrId
			end			
			wkaccount.save
		    redirect_to :controller => controller_name,:action => 'index' , :tab => controller_name
		    flash[:notice] = l(:notice_successful_update)
		else
			flash[:error] = errorMsg #wkaccount.errors.full_messages.join("<br>")
		    redirect_to :controller => controller_name,:action => 'edit', :account_id => wkaccount.id
		end
	end
	
	def destroy
		account = WkAccount.find(params[:id].to_i)
		if account.destroy
			flash[:notice] = l(:notice_successful_delete)
		else
			flash[:error] = account.errors.full_messages.join("<br>")
		end
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end
	
	def getAccountLbl
		l(:label_account)
	end

	def set_filter_session
		if params[:searchlist] == controller_name
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
