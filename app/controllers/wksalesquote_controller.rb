class WksalesquoteController < WkquoteController
  menu_item :wklead

	before_action :require_login

	def newOrderEntity(parentId, parentType)
		newInvoice(parentId, parentType)
	end

	def newInvoice(parentId, parentType)
		invoiceFreq = getInvFreqAndFreqStart
		invIntervals = getIntervals(params[:start_date].to_date, params[:end_date].to_date, invoiceFreq["frequency"], invoiceFreq["start"], true, false)
		if !params[:project_id].blank? && params[:project_id] != '0'
			@projectsDD = Project.where(:id => params[:project_id].to_i).pluck(:name, :id)
			@issuesDD = Issue.where(:project_id => params[:project_id].to_i).pluck(:subject, :id)
			setTempEntity(invIntervals[0][0], invIntervals[0][1], parentId, parentType, params[:populate_items], params[:project_id])
		elsif (!params[:project_id].blank? && params[:project_id] == '0') || params[:isAccBilling] == "true"
			accountProjects = WkAccountProject.where(:parent_type => parentType, :parent_id => parentId.to_i)
			unless accountProjects.blank?
				@projectsDD = accountProjects[0].parent.projects.pluck(:name, :id)
				setTempEntity(invIntervals[0][0], invIntervals[0][1], parentId, parentType, params[:populate_items], params[:project_id])
			else
				client = parentType.constantize.find(parentId)
				flash[:error] = l(:warn_billable_project_not_configured, :name => client.name)
				redirect_to :action => 'new'
			end
		else
			flash[:error] = l(:warning_select_project)
			redirect_to :action => 'new'
		end
	end

	def editOrderEntity
		if params[:invoice_id].present?
			@invoice = WkInvoice.find(params[:invoice_id].to_i)
			@invoiceItem = @invoice.invoice_items
			@invPaymentItems = @invoice.payment_items.current_items
			pjtList = @invoiceItem.select(:project_id).distinct
			pjtList.each do |entry|
				@issuesDD = Issue.where(:project_id => entry.project_id.to_i).pluck(:subject, :id)
				@projectsDD << [ entry.project.name, entry.project_id ] if !entry.project_id.blank? && entry.project_id != 0
			end
		end
	end

	
	def getInvoiceType
		'SQ'
	end

	def showProjectDD
		true
	end

	def getOrderAccountType
		'A'
	end

	def getOrderContactType
		'C'
	end
	
	def getNewHeaderLbl
		l(:label_new_sales_quote)
	end

	def getAdditionalDD
	end
	
	def addQuoteFields
		false
	end

	def getAccountLbl
		l(:field_account)
	end

	def isInvoiceController
		true
	end

	def addAdditionalTax
		false
	end
	
	def getHeaderLabel
		l(:label_sales_quote)
	end
	
	def getItemLabel
		l(:label_sales_quote_items)
	end

	def getAccountDDLbl
		l(:field_account)
	end

	def addLeadDD
		true
	end
end
