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

class WkinvoiceController < WkbillingController
  
before_filter :require_login

include WktimeHelper
include WkinvoiceHelper

	def index
		@projects = nil
		errorMsg = nil
		set_filter_session
		retrieve_date_range
		sqlwhere = ""
	#	accountId = session[:wkinvoice][:account_id]
	#	projectId	= session[:wkinvoice][:project_id]
		filter_type = session[:wkinvoice][:polymorphic_filter]
		contact_id = session[:wkinvoice][:contact_id]
		account_id = session[:wkinvoice][:account_id]
		projectId	= session[:wkinvoice][:project_id]
		parentType = ""
		parentId = ""
		if filter_type == '2' && !contact_id.blank?
			parentType = 'WkCrmContact'
			parentId = 	contact_id
		elsif filter_type == '2' && contact_id.blank?
			parentType = 'WkCrmContact'
		end
		
		if filter_type == '3' && !account_id.blank?
			parentType =  'WkAccount'
			parentId = 	account_id
		elsif filter_type == '3' && account_id.blank?
			parentType =  'WkAccount'
		end
		
		accountProjects = getProjArrays(parentId, parentType)
		@projects = accountProjects.collect{|m| [ m.project_name, m.project_id ] } if !accountProjects.blank?
		
		unless parentId.blank? 
			sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " parent_id = '#{parentId}' "
		end
		
		unless parentType.blank?
			sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " parent_type = '#{parentType}'  "
		end
		
		
		
		unless params[:generate].blank? || !to_boolean(params[:generate])	
			unless projectId.blank? || projectId == 0
				sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
				sqlwhere = sqlwhere + " project_id = '#{projectId}' "
			end
			if filter_type == '2'  || filter_type == '3' 
				WkAccountProject.where(sqlwhere).find_each do |accProj|
					errorMsg = generateInvoices(accProj, projectId, @to + 1, [@from, @to])#accProj.parent_id,accProj.parent_type
				end
			end			
			
			if filter_type == '1'  
				if  projectId.blank?
					accProjects = WkAccountProject.all					
				else
					accProjects = WkAccountProject.where(project_id: projectId)
				end	
				accProjects.each do |accProj|
					errorMsg = generateInvoices(accProj, projectId, @to + 1, [@from, @to])#accProj.parent_id,accProj.parent_type
				end
			end
			
			if errorMsg.blank?	
				redirect_to :action => 'index' , :tab => 'wkinvoice'
				flash[:notice] = l(:notice_successful_update)
			else
				if errorMsg.is_a?(Hash)
					flash[:notice] = l(:notice_successful_update)
					flash[:error] = errorMsg['trans']
				else
					flash[:error] = errorMsg
				end
				redirect_to :action => 'index'
			end	
		else				
			
			if !@from.blank? && !@to.blank?			
				sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
				sqlwhere = sqlwhere + " invoice_date between '#{@from}' and '#{@to}'  "
			end
			
			if filter_type == '1' && (projectId.blank? || projectId == 0)
				invEntries = WkInvoice.includes(:invoice_items)
			else
				invEntries = WkInvoice.includes(:invoice_items).where(sqlwhere)
			end
			# if (!accountId.blank? || accountId.to_i != 0) && (projectId.blank? || projectId == "0")
				# invEntries = invEntries.where(:parent_id => accountId, :parent_type => 'WkAccount')
			# end
			
			# if (accountId.blank? || accountId.to_i == 0) && (!projectId.blank? && projectId != "0")
				# invEntries = invEntries.where( :wk_invoice_items => { :project_id => projectId })
			# end
			
			# if (!accountId.blank? || accountId.to_i != 0) && (!projectId.blank? &&  projectId != "0")
				# invEntries = invEntries.where( :wk_invoice_items => { :project_id => projectId }, :parent_id => accountId, :parent_type => 'WkAccount')
			# end
			
			
			formPagination(invEntries)
			@totalInvAmt = @invoiceEntries.sum("wk_invoice_items.amount")
		end
	end
	
	
	def edit
		@invoice = WkInvoice.find(params[:invoice_id].to_i)
		@invoiceItem = @invoice.invoice_items 
		unless params[:is_report].blank? || !to_boolean(params[:is_report])
			@invoiceItem = @invoiceItem.order(:project_id, :item_type)
			render :action => 'invreport', :layout => false
		end
		
	end
	
	def invreport
		@invoice = WkInvoice.find(params[:invoice_id].to_i)
		@invoiceItem = @invoice.invoice_items 
		render :action => 'invreport', :layout => false
	end
	
	def update
		errorMsg = nil
		invoiceItem = nil
		#invItemId = WkInvoiceItem.select(:id).where(:invoice_id => params["invoice_id"].to_i) 
		#arrId = invItemId.map {|i| i.id }
		@invoice = WkInvoice.find(params["invoice_id"].to_i)
		arrId = @invoice.invoice_items.pluck(:id)
		@invoice.status = params[:field_status]
		if @invoice.status_changed?
			@invoice.closed_on = Time.now
			@invoice.save()
		end
		totalAmount = 0
		tothash = Hash.new
		totalRow = params[:totalrow].to_i
		savedRows = 0
		deletedRows = 0
		#for i in 1..totalRow
		while savedRows < totalRow
			i = savedRows + deletedRows + 1
			if params["item_id#{i}"].blank? && params["project_id#{i}"].blank?
				deletedRows = deletedRows + 1
				next
			end
			unless params["item_id#{i}"].blank?			
				arrId.delete(params["item_id#{i}"].to_i)
				invoiceItem = WkInvoiceItem.find(params["item_id#{i}"].to_i)
				updatedItem = updateInvoiceItem(invoiceItem, params["project_id#{i}"],  params["name#{i}"], params["rate#{i}"].to_f, params["quantity#{i}"].to_f, invoiceItem.currency)
			else
				invoiceItem = @invoice.invoice_items.new
				updatedItem = updateInvoiceItem(invoiceItem, params["project_id#{i}"], params["name#{i}"], params["rate#{i}"].to_f, params["quantity#{i}"].to_f, params["currency#{i}"])
			end
			savedRows = savedRows + 1
			tothash[updatedItem.project_id] = [(tothash[updatedItem.project_id].blank? ? 0 : tothash[updatedItem.project_id][0]) + updatedItem.amount, updatedItem.currency]
		end
		
		if !arrId.blank?
			deleteBilledEntries(arrId)
			WkInvoiceItem.delete_all(:id => arrId)
		end
		
		accountId = @invoice.parent_id		
		tothash.each do|key, val|
			accountProject = WkAccountProject.where("project_id = ?  and parent_id = ? and parent_type = ? ", key, accountId, 'WkAccount')
			addTaxes(accountProject[0], val[1], val[0])
		end
		
		unless @invoice.id.blank?
			totalAmount = @invoice.invoice_items.sum(:amount)
			if (totalAmount.round - totalAmount) != 0
				addRoundInvItem(totalAmount)
			end
			if totalAmount > 0 && autoPostGL
				glTransaction = postToGlTransaction(@invoice, totalAmount.round, @invoice.invoice_items[0].currency)
				unless glTransaction.blank?
					@invoice.gl_transaction_id = glTransaction.id
					@invoice.save
				end				
			end
		end
		
		if errorMsg.nil? 
			redirect_to :action => 'index' , :tab => 'wkinvoice'
			flash[:notice] = l(:notice_successful_update)
	   else
			flash[:error] = errorMsg
			redirect_to :action => 'edit', :invoice_id => @invoice.id
	   end
	end
	
	def destroy
		invoice = WkInvoice.find(params[:invoice_id].to_i)#.destroy
		deleteBilledEntries(invoice.invoice_items.pluck(:id))
		invoice.destroy
		flash[:notice] = l(:notice_successful_delete)
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end
	
	def deleteBilledEntries(invItemIdsArr)
		CustomField.find(getSettingCfId('wktime_billing_id_cf')).custom_values.where(:value => invItemIdsArr).delete_all unless getSettingCfId('wktime_billing_id_cf').blank? || getSettingCfId('wktime_billing_id_cf') == 0
	end
  
    def getAccountProjIds
		accArr = ""	
		accProjId = getProjArrays(params[:parent_id], params[:parent_type] )
		if !accProjId.blank?
			accProjId.each do | entry|
				accArr <<  entry.project_id.to_s() + ',' + entry.project_name.to_s()  + "\n" 
			end
		end
		respond_to do |format|
			format.text  { render :text => accArr }
		end
		
    end
	
	def getProjArrays(parent_id, parent_type)		
		sqlStr = "left outer join projects on projects.id = wk_account_projects.project_id "
		if !parent_id.blank? && !parent_type.blank?
				sqlStr = sqlStr + " where wk_account_projects.parent_id = #{parent_id} and wk_account_projects.parent_type = '#{parent_type}' "
		end
		
		WkAccountProject.joins(sqlStr).select("projects.name as project_name, projects.id as project_id").distinct(:project_id)
	end
	
  	def set_filter_session
        if params[:searchlist].blank? && session[:wkinvoice].nil?
			session[:wkinvoice] = {:period_type => params[:period_type],:period => params[:period], :contact_id => params[:contact_id], :account_id => params[:account_id], :project_id => params[:project_id], :polymorphic_filter =>  params[:polymorphic_filter], :from => @from, :to => @to}
		elsif params[:searchlist] =='wkinvoice'
			session[:wkinvoice][:period_type] = params[:period_type]
			session[:wkinvoice][:period] = params[:period]
			session[:wkinvoice][:from] = params[:from]
			session[:wkinvoice][:to] = params[:to]
			session[:wkinvoice][:contact_id] = params[:contact_id]
			session[:wkinvoice][:project_id] = params[:project_id]
			session[:wkinvoice][:account_id] = params[:account_id]
			session[:wkinvoice][:polymorphic_filter] = params[:polymorphic_filter]
		end
		
   end
   
   # Retrieves the date range based on predefined ranges or specific from/to param dates
	def retrieve_date_range
		@free_period = false
		@from, @to = nil, nil
		period_type = session[:wkinvoice][:period_type]
		period = session[:wkinvoice][:period]
		fromdate = session[:wkinvoice][:from]
		todate = session[:wkinvoice][:to]
		
		if (period_type == '1' || (period_type.nil? && !period.nil?)) 
		    case period.to_s
			  when 'today'
				@from = @to = Date.today
			  when 'yesterday'
				@from = @to = Date.today - 1
			  when 'current_week'
				@from = getStartDay(Date.today - (Date.today.cwday - 1)%7)
				@to = @from + 6
			  when 'last_week'
				@from =getStartDay(Date.today - 7 - (Date.today.cwday - 1)%7)
				@to = @from + 6
			  when '7_days'
				@from = Date.today - 7
				@to = Date.today
			  when 'current_month'
				@from = Date.civil(Date.today.year, Date.today.month, 1)
				@to = (@from >> 1) - 1
			  when 'last_month'
				@from = Date.civil(Date.today.year, Date.today.month, 1) << 1
				@to = (@from >> 1) - 1
			  when '30_days'
				@from = Date.today - 30
				@to = Date.today
			  when 'current_year'
				@from = Date.civil(Date.today.year, 1, 1)
				@to = Date.civil(Date.today.year, 12, 31)
	        end
		elsif period_type == '2' || (period_type.nil? && (!fromdate.nil? || !todate.nil?))
		    begin; @from = fromdate.to_s.to_date unless fromdate.blank?; rescue; end
		    begin; @to = todate.to_s.to_date unless todate.blank?; rescue; end
		    @free_period = true
		else
		  # default
		  # 'current_month'		
			@from = Date.civil(Date.today.year, Date.today.month, 1)
			@to = (@from >> 1) - 1
	    end    
		
		@from, @to = @to, @from if @from && @to && @from > @to

	end
	
	def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		@invoiceEntries = entries.order(:id).limit(@limit).offset(@offset)
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

end