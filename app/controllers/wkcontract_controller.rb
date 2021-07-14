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

class WkcontractController < WkbillingController

before_action :require_login
menu_item :wkinvoice


	def index
		sort_init 'id', 'asc'
		sort_update 'contract_number' => "contract_number",
				'start_date' => "start_date",
				'end_date' => "end_date",
				'project' => "projects.name",
				'type' => "parent_type",
				'name' => "CASE WHEN wk_contracts.parent_type = 'WkAccount' THEN a.name ELSE CONCAT(c.first_name, c.last_name) END"
		@contract_entries = nil
		sqlwhere = ""
		set_filter_session
		filter_type = session[controller_name].try(:[], :polymorphic_filter)
		contact_id = session[controller_name].try(:[], :contact_id)
		account_id = session[controller_name].try(:[], :account_id)
		projectId	= session[controller_name].try(:[], :project_id)
				
		if filter_type == '2' && !contact_id.blank?
			sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " parent_id = '#{contact_id}'  and parent_type = 'WkCrmContact'  "
		elsif filter_type == '2' && contact_id.blank?
			sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " parent_type = 'WkCrmContact'  "
		end
		
		if filter_type == '3' && !account_id.blank?
			sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " parent_id = '#{account_id}'  and parent_type = 'WkAccount'  "
		elsif filter_type == '3' && account_id.blank?
			sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " parent_type = 'WkAccount'  "
		end
		
		unless projectId.blank?
			sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " project_id = '#{projectId}' " 
		end
		entries = WkContract.joins("LEFT JOIN (SELECT id, name FROM projects) AS projects ON projects.id = wk_contracts.project_id
			LEFT JOIN wk_accounts a on (wk_contracts.parent_type = 'WkAccount' and wk_contracts.parent_id = a.id)
			LEFT JOIN wk_crm_contacts c on (wk_contracts.parent_type = 'WkCrmContact' and wk_contracts.parent_id = c.id)").all
		unless filter_type == '1' && projectId.blank? 
			entries = entries.where(sqlwhere)
		end
		entries = entries.reorder(sort_clause)
		respond_to do |format|
			format.html do
				formPagination(entries)
				render :layout => !request.xhr?
			end
			format.csv do
				headers = {contract_number: l(:label_contract_number), type: l(:field_type), name: l(:field_name), project: l(:label_project), start_date: l(:label_start_date), end_date: l(:label_end_date) }
				data = entries.map do |e|
					type = e.parent_type == 'WkAccount' ? 'Account' : 'Contact'
					{ contract_number: e.contract_number, type:  type, name: (e&.parent&.name || ''), project: (e&.project&.name || ""), start_date: e.start_date, end_date: e.end_date }
				end
				send_data(csv_export(headers: headers, data: data), type: "text/csv; header=present", filename: "contract.csv")
			end
		end
	end

	def set_filter_session
		filters = [:contact_id, :project_id, :account_id, :polymorphic_filter]
		super(filters)
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
	
	
   def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		@contract_entries = entries.limit(@limit).offset(@offset)
	end
	
    def edit
	     @contractEntry = nil
		 unless params[:contract_id].blank?
			@contractEntry = WkContract.find(params[:contract_id])
		 else 
			@contractEntry = @contractEntry
		 end
    end

		def update
		errorMsg = nil
	    if params[:contract_id].blank? || params[:contract_id].to_i == 0
		    wkContract = WkContract.new 
	    else
		    wkContract = WkContract.find(params[:contract_id].to_i)
	    end
		wkContract.project_id = params[:project_id]
		wkContract.parent_id = params[:related_parent].to_i
		wkContract.parent_type = params[:related_to]
		wkContract.contract_number = getPluginSetting('wktime_contract_no_prefix')
		wkContract.start_date = params[:start_date]
		wkContract.end_date = params[:end_date]
		unless wkContract.save
			errorMsg = wkContract.errors.full_messages.join("<br>")
		end	
		if errorMsg.blank?
			wkContract.contract_number = getPluginSetting('wktime_contract_no_prefix') + wkContract.id.to_s
			wkContract.save
			#for attachment save
			errorMsg = save_attachments(wkContract.id) if params[:attachments].present?
			#for mail notification
			WkContract.send_notification(wkContract)
			redirect_to :controller => 'wkcontract',:action => 'index' , :tab => 'wkcontract'
		    flash[:notice] = l(:notice_successful_update)
		else
			redirect_to :controller => 'wkcontract',:action => 'edit',:contract_id => params[:contract_id] , :tab => 'wkcontract'
		    flash[:error] = errorMsg
			
		end
    end	
	
	def destroy
		WkContract.find(params[:contract_id].to_i).destroy
		flash[:notice] = l(:notice_successful_delete)
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end	
end