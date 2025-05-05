# ERPmine - ERP for service industry
# Copyright (C) 2011-2021  Adhi software pvt ltd
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

  include WktimeHelper
  include WkleadHelper
  include WkaccountprojectHelper
	include WksalesquoteHelper
  accept_api_auth :index, :edit, :update

	def index
		sort_init 'updated_at', 'desc'

		sort_update 'lead_name' => "CONCAT(wk_crm_contacts.first_name, wk_crm_contacts.last_name)",
			'status' => "#{WkLead.table_name}.status",
			'location_name' => "wk_locations.name",
			'acc_name' => "wk_accounts.name",
			'updated_by_user_id' => "CONCAT(users.firstname, users.lastname)",
			'updated_at' => "#{WkLead.table_name}.updated_at"

		set_filter_session
		leadName = session[controller_name].try(:[], :lead_name)
		status = session[controller_name].try(:[], :status)
		locationId = session[controller_name].try(:[], :location_id)
		location = WkLocation.where(:is_default => 'true').first

		entries = WkLead.left_joins(:created_by_user, :account, :contact, :contact => :location)
		.where.not(wk_crm_contacts: { contact_type: 'IC' })

		if !leadName.blank? && !status.blank?
		    entries = entries.where(:status => status).where("LOWER(wk_crm_contacts.first_name) like LOWER(?) OR LOWER(wk_crm_contacts.last_name) like LOWER(?)", "%#{leadName}%", "%#{leadName}%")
		elsif !leadName.blank? && status.blank?
			entries = entries.where.not(:status => 'C').where("LOWER(wk_crm_contacts.first_name) like LOWER(?) OR LOWER(wk_crm_contacts.last_name) like LOWER(?)", "%#{leadName}%", "%#{leadName}%")
		elsif leadName.blank? && !status.blank?
			entries = entries.where(:status => status).where("LOWER(wk_crm_contacts.first_name) like LOWER(?) OR LOWER(wk_crm_contacts.last_name) like LOWER(?)", "%#{leadName}%", "%#{leadName}%")
		else
			entries = entries.where.not(:status => 'C')
		end

		if (!locationId.blank? || !location.blank?) && locationId != "0"
			location_id = !locationId.blank? ? locationId.to_i : location.id.to_i
			entries = entries.where("wk_crm_contacts.location_id = ? ", location_id)
		end
		entries = entries.reorder(sort_clause)
		respond_to do |format|
			format.html do
				formPagination(entries)
			  render :layout => !request.xhr?
			end
			format.api do
				@leadEntries = entries
			end
			format.csv do
				headers = { name: l(:field_name), status: l(:field_status), acc_name: l(:label_account_name), location: l(:field_location), phone: l(:label_work_phone), email: l(:field_mail), modified: l(:field_status_modified_by), Updated: l(:field_updated_on) }
				data = entries.map do |e|
					{ name: e&.contact&.name, status: getLeadStatusHash[e.status], acc_name: (e&.account&.name || ''),  location: (e&.contact&.location&.name || ''), phone: (e&.contact&.address&.work_phone || ''), email: (e&.contact&.address&.email || ''), modified: e.created_by_user.name(:firstname_lastname), Updated: e.updated_at.localtime.strftime("%Y-%m-%d %H:%M:%S")}
				end
				respond_to do |format|
					format.csv {
						send_data(csv_export({headers: headers, data: data}), type: 'text/csv; header=present', filename: 'lead.csv')
					}
				end
			end
		end
	end

	def show
		@lead = nil
		@lead = WkLead.find(params[:lead_id]) unless params[:lead_id].blank?
		@lead
	end

	def edit
		@lead = nil
		if params[:lead_id].present?
			@lead = WkLead.find(params[:lead_id])
			@accountproject = formPagination(accountProjctList)
			@invoiceEntries = formPagination(salesQuoteList(params[:lead_id], 'WkLead'))
		end
		@lead
	end

	def update
		if api_request?
			(params[:address] || []).each{|addr| params[addr.first] = addr.last }
			params.delete("address")
		end
		wkLead = update_without_redirect
		errorMsg = save_attachments(wkLead.id) if params[:attachments].present?
		respond_to do |format|
			format.html {
				if @wkContact.valid?
					if params[:wklead_save_convert] || @isConvert
						redirect_to :action => 'convert', :lead_id => wkLead.id
					else
						redirect_to :action => 'index' , :tab => controller_name
						flash[:notice] = l(:notice_successful_update)
					end
				else
					flash[:error] = @wkContact.errors.full_messages.join("<br>")
						redirect_to :action => 'edit', :lead_id => wkLead.id
				end
			}
			format.api{
				errorMsg = @wkContact.errors.full_messages.join("<br>") + (errorMsg || "")
				if errorMsg.blank?
					if params[:wklead_save_convert].present?
						leadConvert(params)
					end
					render :plain => errorMsg, :layout => nil
				else
					@error_messages = errorMsg.split('\n')
					render :template => 'common/error_messages', :format => [:api], :status => :unprocessable_entity, :layout => nil
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
		l(:field_account)
	end

	def set_filter_session(filters=nil, filterParams={})
		filters = [:lead_name, :status, :location_id] if filters.blank?
		super(filters, filterParams)
	end
end
