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

class WkaccountprojectController < WkbaseController

before_action :require_login
before_action :account_project_permission
before_action :check_account_proj_module_permission

include WkaccountprojectHelper

		def index
			sort_init 'id', 'asc'
			sort_update 'type' => "parent_type",
									'name' => "CASE WHEN wk_account_projects.parent_type = 'WkAccount' THEN a.name ELSE CONCAT(c.first_name, c.last_name) END",
									'project' => "projects.name",
									'billing_type' => "billing_type"
			set_filter_session
			entries = accountProjctList
			entries = entries.joins("LEFT JOIN wk_accounts a on (wk_account_projects.parent_type = 'WkAccount' and wk_account_projects.parent_id = a.id)
				LEFT JOIN wk_crm_contacts c on (wk_account_projects.parent_type = 'WkCrmContact' and wk_account_projects.parent_id = c.id)")
			formPagination(entries.reorder(sort_clause))
    end
	
	def edit
		@accProjEntry = nil
		unless params[:acc_project_id].blank?
			@accProjEntry = WkAccountProject.find(params[:acc_project_id].to_i)			
			@wkbillingschedule = WkBillingSchedule.where("account_project_id = ? ", params[:acc_project_id].to_i)
			stax = @accProjEntry.taxes
			@selectedtax = stax.map { |r| r.id } #stax.collect{|m| [  m.id ] }
		end		
		taxentry = WkTax.all
		@taxentry = taxentry.collect{|m| [ m.name, m.id ] }
		
	end
	
	def update
		errorMsg = nil
		wkaccountproject = nil
		wkbillingschedule = nil
		wkaccprojecttax = nil
		arrId = []
		wkaccountproject = saveBillableProjects(params[:accountProjectId], params[:project_id], params[:related_parent], params[:related_to], params[:applytax], params[:itemized_bill], params[:billing_type])
		
		unless wkaccountproject.id.blank?
			
			if wkaccountproject.apply_tax 
				taxId = params[:tax_id]	
				WkAccProjectTax.where(:account_project_id => wkaccountproject.id).where.not(:tax_id => taxId).delete_all()
				unless taxId.blank?
					taxId.collect{ |id| 
						istaxid = WkAccProjectTax.where("account_project_id = ? and tax_id = ? ", wkaccountproject.id, id).count
						unless istaxid > 0
							wkaccprojecttax = WkAccProjectTax.new
							wkaccprojecttax.account_project_id = wkaccountproject.id
							wkaccprojecttax.tax_id = id
							if !wkaccprojecttax.save()
								errorMsg = wkaccountproject.errors.full_messages.join("<br>")
							end
						end						
					}
				end
			else
				WkAccProjectTax.where(:account_project_id => wkaccountproject.id).delete_all()
			end
			
			if wkaccountproject.billing_type == 'FC'
				milestonelength = params[:mtotalrow].to_i
				for i in 1..milestonelength
					if params["milestone_id#{i}"].blank? 
						wkbillingschedule = WkBillingSchedule.new
						wkbillingschedule.invoice_id = ""
					else 
						wkbillingschedule = WkBillingSchedule.find(params["milestone_id#{i}"].to_i)
						arrId << params["milestone_id#{i}"].to_i
					end
					wkbillingschedule.milestone = params["milestone#{i}"]
					wkbillingschedule.bill_date = params["billdate#{i}"]#.strftime('%F')
					wkbillingschedule.amount = params["amount#{i}"]
					wkbillingschedule.currency = params["currency#{i}"]
					wkbillingschedule.account_project_id = wkaccountproject.id
					if wkbillingschedule.save()	
						arrId << wkbillingschedule.id
					else
						errorMsg =  wkbillingschedule.errors.full_messages.join("<br>")
					end
				end
			end
			WkBillingSchedule.where(:account_project_id => wkaccountproject.id).where.not(:id => arrId).delete_all()
		end
		projectEntry = Project.find(params[:project_id])
		if errorMsg.nil? 
			redirect_to :project_id => projectEntry.identifier, :controller => controller_name, :action => 'index'
			flash[:notice] = l(:notice_successful_update)
	    else
			flash[:error] = errorMsg
			redirect_to :action => 'edit', :acc_project_id => wkaccountproject.id
	    end
	end
	
	def destroy
		projectEntry = Project.find(params[:project_id])
		WkAccountProject.find(params[:account_project_id].to_i).destroy
		
		flash[:notice] = l(:notice_successful_delete)
		redirect_back_or_default :project_id => projectEntry.identifier, :action => 'index'
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
		@accountproject = entries.limit(@limit).offset(@offset)
	end

	def account_project_permission
		project_id = params[:project_id]
		params[:project_id] = (Project.all).first.identifier if params[:project_id].blank?
		contact_id = params[:contact_id].blank? ? nil : WkCrmContact.where(:id => params[:contact_id])
		contact_id = (contact_id.first).id unless contact_id.blank?
		account_id = params[:account_id].blank? ? nil : WkAccount.where(:id => params[:account_id])
		account_id = (account_id.first).id unless account_id.blank?

		if !showCRMModule
			render_403 
			return false
		elsif project_id.blank? && contact_id.blank? && account_id.blank?
			render_404
			return false
		elsif !params[:project_id].blank?
			find_project_by_project_id
		end
	end

	def check_account_proj_module_permission
		if params[:contact_id].blank? && params[:account_id].blank? && !params[:project_id].blank? && !User.current.allowed_to?(:view_accounts, @project)
			render_403
			return false
		end
	end
	   
	def getOrderContactType
		'C'
	end

	def additionalContactType
		true
	end

	def getOrderAccountType
		'A'
	end

	def getAccountDDLbl
		l(:label_account)
	end

	def getAdditionalDD
	end	
end
