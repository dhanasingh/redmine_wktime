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

class WkaccountprojectController < WkbillingController

before_filter :require_login

    def index
		@accountproject = nil
		sqlwhere = ""
		set_filter_session
		filter_type = session[:accountproject][:polymorphic_filter]
		contact_id = session[:accountproject][:contact_id]
		account_id = session[:accountproject][:account_id]
		projectId	= session[:accountproject][:project_id]
				
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
		
		# if accountId.blank? &&  !projectId.blank?
			# sqlwhere = "project_id = #{projectId}"
		# end
		# if !accountId.blank? &&  projectId.blank?
			# sqlwhere = "parent_id = #{accountId} and parent_type = 'WkAccount' "
		# end
		# if !accountId.blank? &&  !projectId.blank?
			# sqlwhere = "parent_id = #{accountId} and parent_type = 'WkAccount' and project_id = #{projectId}"
		# end
		
		if filter_type == '1' && projectId.blank?  #accountId.blank? && projectId.blank?
			entries = WkAccountProject.all
		else
			entries = WkAccountProject.where(sqlwhere)
		end	
		formPagination(entries)	
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
		if !params[:accountProjectId].blank?
			wkaccountproject = WkAccountProject.find(params[:accountProjectId].to_i)
		else
			wkaccountproject = WkAccountProject.new
		end
		
		wkaccountproject.project_id = params[:project_id].to_i
		wkaccountproject.parent_id = params[:related_parent].to_i
		wkaccountproject.parent_type = params[:related_to]
		wkaccountproject.apply_tax = params[:applytax]
		wkaccountproject.itemized_bill = params[:itemized_bill]
		wkaccountproject.billing_type = params[:billing_type]
		
		if !wkaccountproject.save			
			errorMsg = wkaccountproject.errors.full_messages.join("<br>")
		end
		
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
					if params["milestone_id#{i}"].blank? #&& !params["milestone#{i}"].blank?
						wkbillingschedule = WkBillingSchedule.new
						wkbillingschedule.invoice_id = ""
					else # if !params["milestone_id#{i}"].blank?
						wkbillingschedule = WkBillingSchedule.find(params["milestone_id#{i}"].to_i)
						arrId << params["milestone_id#{i}"].to_i
					end
					wkbillingschedule.milestone = params["milestone#{i}"]
					wkbillingschedule.bill_date = params["billdate#{i}"]#.strftime('%F')
					wkbillingschedule.amount = params["amount#{i}"]
					wkbillingschedule.currency = params["currency#{i}"]
					#wkbillingschedule.invoice_id = ""
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
				
		if errorMsg.nil? 
			redirect_to :action => 'index' , :tab => 'wkaccountproject'
			flash[:notice] = l(:notice_successful_update)
	    else
			flash[:error] = errorMsg
			redirect_to :action => 'edit', :acc_project_id => wkaccountproject.id
	    end
	end
	
	def destroy
		WkAccountProject.find(params[:account_project_id].to_i).destroy
		
		flash[:notice] = l(:notice_successful_delete)
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end	  
    
    def set_filter_session
        if params[:searchlist].blank? && session[:accountproject].nil?
			session[:accountproject] = {:contact_id => params[:contact_id], :account_id => params[:account_id], :project_id => params[:project_id], :polymorphic_filter =>  params[:polymorphic_filter] }
		elsif params[:searchlist] =='accountproject'
			session[:accountproject][:contact_id] = params[:contact_id]
			session[:accountproject][:project_id] = params[:project_id]
			session[:accountproject][:account_id] = params[:account_id]
			session[:accountproject][:polymorphic_filter] = params[:polymorphic_filter]
		end
		
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

end
