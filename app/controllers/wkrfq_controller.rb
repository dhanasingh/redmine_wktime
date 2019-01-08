class WkrfqController < ApplicationController
  unloadable
  include WktimeHelper
  before_filter :require_login
  before_filter :check_perm_and_redirect, :only => [:index, :edit, :update]
  before_filter :check_pur_admin_and_redirect, :only => [:destroy]

    def index
		@rfqEntries = nil
		sqlStr = ""
		unless params[:rfqname].blank?
			sqlStr = "LOWER(name) like LOWER('%#{params[:rfqname]}%')"
		end
		unless params[:rfq_date].blank?
			sqlStr = sqlStr + " AND" unless sqlStr.blank?
			sqlStr = sqlStr + " '#{params[:rfq_date]}' between start_date and end_date"
		end
		unless sqlStr.blank?
			entries = WkRfq.where(sqlStr)
		else
			entries = WkRfq.all
		end
		formPagination(entries)
    end
	
	def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		@rfqEntries = entries.limit(@limit).offset(@offset)
	end
	
	def edit
	    @rfqEntry = nil
	    unless params[:rfq_id].blank?
		   @rfqEntry = WkRfq.find(params[:rfq_id])
		end 
	end	
    
	def update	
		if params[:rfq_id].blank?
		  rfq = WkRfq.new
		else
		  rfq = WkRfq.find(params[:rfq_id])
		end
		rfq.name = params[:name]
		rfq.status = params[:status] unless params[:status].blank?
		rfq.start_date = params[:start_date]
		rfq.end_date = params[:end_date]
		rfq.description = params[:description]
		if rfq.save()
		    redirect_to :controller => 'wkrfq',:action => 'index' , :tab => 'wkrfq'
		    flash[:notice] = l(:notice_successful_update)
		else
		    redirect_to :controller => 'wkrfq',:action => 'index' , :tab => 'wkrfq'
		    flash[:error] = rfq.errors.full_messages.join("<br>")
		end
    end
	
	def destroy
		#WkRfq.find(params[:rfq_id].to_i).destroy
		#flash[:notice] = l(:notice_successful_delete)
		rfq = WkRfq.find(params[:rfq_id].to_i)
		if rfq.destroy
			flash[:notice] = l(:notice_successful_delete)
		else
			flash[:error] = rfq.errors.full_messages.join("<br>")
		end
		redirect_back_or_default :action => 'index', :tab => params[:tab]
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
	
	def deletePermission
		isModuleAdmin('wktime_pur_admin')
	end
	
	def check_perm_and_redirect
		unless check_permission
			render_403
			return false
		end
	end
	
	def check_permission		
		return isModuleAdmin('wktime_pur_group') || isModuleAdmin('wktime_pur_admin') 
	end
	
	def check_pur_admin_and_redirect
	  unless isModuleAdmin('wktime_pur_admin') 
	    render_403
	    return false
	  end
    end

end
