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

before_filter :require_login

    def index
		@account_entries = nil
		if params[:accountname].blank?
		   entries = WkAccount.where(:account_type => getAccountType)
		else
			entries = WkAccount.where(:account_type => getAccountType).where("name like ?", "%#{params[:accountname]}%")
		end
		formPagination(entries)
    end
	
	def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		@account_entries = entries.order(:name).limit(@limit).offset(@offset)
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
		#wkaccount.address_id =  wkaddress.id
		wkaccount.name = params[:account_name]
		wkaccount.account_type = getAccountType
		wkaccount.account_category = params[:account_category]
		wkaccount.description = params[:description]
		wkaccount.account_billing = params[:account_billing].blank? ? 0 : params[:account_billing]
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
end
