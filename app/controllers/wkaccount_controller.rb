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
	include WksalesquoteHelper
    before_action :require_login

	def index
		sort_init "updated_at", "desc"

		sort_update "acc_name" => "#{WkAccount.table_name}.name",
					"country" => "A.country",
					"city" => "A.city",
					"location_name" => "L.name",
					"updated_at" => "#{WkAccount.table_name}.updated_at",
					"acc_number" => "#{WkAccount.table_name}.account_number"

		set_filter_session
		locationId = session[controller_name].try(:[], :location_id)
		accName = session[controller_name].try(:[], :accountname)
		@account_entries = nil
		location = WkLocation.where(:is_default => 'true').first

		entries = WkAccount.includes(:location, :address)

		if accName.blank?
			entries = entries.where(:account_type => getAccountType)
		else
			entries = entries.where(:account_type => getAccountType).where("lower(wk_accounts.name) like ?", "%#{accName.downcase}%")
		end
		if (!locationId.blank? || !location.blank?) && locationId != "0"
			location_id = !locationId.blank? ? locationId.to_i : location.id.to_i
			entries = entries.where(:location_id => location_id)
		end
		entries = entries.reorder(sort_clause)
		respond_to do |format|
			format.html do
				formPagination(entries)
			  render :layout => !request.xhr?
			end
			format.api do
				@account_entries = entries
			end
			format.csv do
				headers = { name: l(:field_name), location: l(:field_location), address: l(:label_address), phone: l(:label_work_phone), country: l(:label_country), city: l(:label_city) }
  			data = entries.map do |e|
					{ name: e.name, location: (e&.location&.name || ''), address: (e&.address&.address1 || ''),  phone: (e&.address&.work_phone || ''), country: (e&.address&.country || ''), city: (e&.address&.city || '')}
				end
				respond_to do |format|
					format.csv {
						send_data(csv_export({headers: headers, data: data}), type: 'text/csv; header=present', filename: 'account.csv')
					}
				end
			end
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
			@invoiceEntries = formPagination(salesQuoteList(params[:account_id], 'WkAccount'))
		end
		respond_to do |format|
			format.html do
				render :layout => !request.xhr?
			end
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
					render :template => 'common/error_messages', :format => [:api], :status => :unprocessable_entity, :layout => nil
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
		l(:field_account)
	end

	def set_filter_session
		filters = [:location_id, :accountname]
		super(filters)
	end

end
