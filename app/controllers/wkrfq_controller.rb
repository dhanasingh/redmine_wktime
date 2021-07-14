class WkrfqController < WkbaseController
  unloadable
  include WktimeHelper
  include WkorderentityHelper
  include WkrfqHelper
  before_action :require_login
  before_action :check_perm_and_redirect, :only => [:index, :edit, :update]
  before_action :check_pur_admin_and_redirect, :only => [:destroy]

    def index
		sort_init 'id', 'asc'
		sort_update 'name' => "name",
					'status' => "status",
					'start_date' => "start_date",
					'end_date' => "end_date"

		set_filter_session
		rfq_name = session[controller_name].try(:[], :rfq_name)
		rfq_date = session[controller_name].try(:[], :rfq_date)
		@rfqEntries = nil
		sqlStr = ""
		unless rfq_name.blank?
			sqlStr = "LOWER(name) like LOWER('%#{rfq_name}%')"
		end
		unless rfq_date.blank?
			sqlStr = sqlStr + " AND" unless sqlStr.blank?
			sqlStr = sqlStr + " '#{rfq_date}' between start_date and end_date"
		end
		unless sqlStr.blank?
			entries = WkRfq.where(sqlStr)
		else
			entries = WkRfq.all
		end
		entries = entries.reorder(sort_clause)
		respond_to do |format|
			format.html {
				formPagination(entries, "list")
			}
			format.csv{
				headers = {name: l(:field_name), status: l(:field_status), start_date: l(:label_start_date), end_date: l(:label_end_date)}
				data = entries.map{|entry| {name: entry.name, status: getRfqStatusHash[entry.status], start_date: entry.start_date, end_date: entry.end_date} }
				send_data(csv_export(headers: headers, data: data), type: "text/csv; header=present", filename: "rfq.csv")
			}
		end
    end
	
	def formPagination(entries, sectiontype)
		@entry_count = entries.count
        setLimitAndOffset()
		if(sectiontype == "list")
			@rfqEntries = entries.limit(@limit).offset(@offset)
		else
			@invoiceEntries = entries.order(:id).limit(@limit).offset(@offset)
		end
	end
	
	def edit
	    @rfqEntry = nil
	    unless params[:rfq_id].blank?
		   @rfqEntry = WkRfq.find(params[:rfq_id])
			quoteList()
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
		validateERPPermission("A_PUR_PRVLG")
	end
	
	def check_perm_and_redirect
		unless check_permission
			render_403
			return false
		end
	end
	
	def check_permission		
		return validateERPPermission("B_PUR_PRVLG") || validateERPPermission("A_PUR_PRVLG") 
	end
	
	def check_pur_admin_and_redirect
	  unless validateERPPermission("A_PUR_PRVLG") 
	    render_403
	    return false
	  end
    end
	
	def controller_name
		if action_name == "edit"
			"wkquote"
		else
			"wkrfq"
		end
	end
	
	def quoteList
		rfqId = params[:rfq_id]
		invIds = getInvoiceIds(rfqId, 'Q', false)
		invEntries = WkInvoice.includes(:invoice_items).where( :id => invIds)
		formPagination(invEntries, "quote")
	end
	
	def getLabelInvNum
		l(:label_quote_number)
	end
	
	def getDateLbl
		l(:label_quote_date)
	end
	
	def isInvPaymentLink
		false
	end  

	def set_filter_session
		filters = [:rfq_name, :rfq_date]
		super(filters)
	end
end
