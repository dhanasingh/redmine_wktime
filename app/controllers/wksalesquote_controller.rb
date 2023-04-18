class WksalesquoteController < WkquoteController
  menu_item :wklead
	@@sqmutex = Mutex.new

	before_action :require_login

  before_action :check_perm_and_redirect, :only => [:index, :edit, :update]
  before_action :check_crm_admin_and_redirect, :only => [:destroy]
	include WkorderentityHelper

	def newOrderEntity(parentId, parentType)
		setupNewInvoice(parentId, parentType, params[:start_date], params[:end_date])
	end
	
	def setTempEntity(startDate, endDate, parentID, parentType, populatedItems, projectID)
		@currency = params[:inv_currency]
		super
		@invoice = WkInvoice.find(params[:invoice_id].to_i) if params[:invoice_id].present?
		if populatedItems
			@unbilled = true
			if projectID == '0'
				accountProjects = WkAccountProject.where(parent_type: parentType, parent_id: parentID.to_i)
			else
				accountProjects = WkAccountProject.where(parent_type: parentType, parent_id: parentID.to_i, project_id: projectID)
			end
			accountProjects.each do |acc_proj|
				if acc_proj.billing_type == 'TM'
					issues = getProjIssues(acc_proj.project_id.to_i)
					if @invoiceItem.present?
						issue_id = @invoiceItem.pluck(:invoice_item_id)
						issues = issues.where.not(id: issue_id) if issue_id.present?
					end
					issues.each do |issue|
						invoice_items = {}
						rate = getBillingRate(issue.project_id, issue.id)
						quantity = getIssueEstimatedHours(issue.id)
						amount = (rate || 0) * (quantity || 0)
						invoice_items = {project_id: issue.project_id, item_desc: issue.subject, rate: rate, item_quantity: quantity, item_amount: amount.round(2), billing_type: acc_proj.billing_type, issue_id: issue.id}
						loadInvItems(invoice_items)
					end
				else
					@currency = acc_proj.wk_billing_schedules&.first&.currency
					scheduledEntries = acc_proj.wk_billing_schedules.where(account_project_id: acc_proj.id)
					scheduledEntries.each do |entry|
						invoice_items = {}
						itemDesc = ""
						if isAccountBilling(entry.account_project)
							itemDesc = entry.account_project.project.name + " - " + entry.milestone
						else
							itemDesc = entry.milestone
						end
						invoice_items = {project_id: entry.account_project.project_id, item_desc: itemDesc, rate: entry.amount, item_quantity: 1, item_amount: entry.amount.round(2), billing_type: entry.account_project.billing_type, milestone_id: entry.id}
						loadInvItems(invoice_items)
					end
				end
			end
		end
	end

	def loadInvItems(invoice_items)
		@invItems[@itemCount].store 'milestone_id', invoice_items[:milestone_id] if invoice_items[:billing_type] == 'FC'
		@invItems[@itemCount].store 'project_id', invoice_items[:project_id]
		@invItems[@itemCount].store 'item_desc', invoice_items[:item_desc]
		@invItems[@itemCount].store 'item_type', 'i'
		@invItems[@itemCount].store 'rate', invoice_items[:rate]
		@invItems[@itemCount].store 'currency', @currency || Setting.plugin_redmine_wktime['wktime_currency']
		@invItems[@itemCount].store 'item_quantity', invoice_items[:item_quantity]
		@invItems[@itemCount].store 'item_amount', invoice_items[:item_amount]
		@invItems[@itemCount].store 'issue_id', invoice_items[:issue_id]  if invoice_items[:billing_type] == 'TM'
		@invItems[@itemCount].store 'billing_type', invoice_items[:billing_type]
		@itemCount = @itemCount + 1
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

	def deletePermission
		validateERPPermission("A_CRM_PRVLG")
	end

	def needChangedProject
		true
	end

	def addAllRows
		true
	end
	
	def getOrderNumberPrefix
		'wktime_sales_quote_no_prefix'
	end

	def check_perm_and_redirect
		unless check_permission
			render_403
			return false
		end
	end

	def check_permission
		return validateERPPermission("B_CRM_PRVLG") || validateERPPermission("A_CRM_PRVLG")
	end
	
	def check_crm_admin_and_redirect
		unless validateERPPermission("A_CRM_PRVLG")
			render_403
			return false
		end
	end

	def saveOrderInvoice(parentId, parentType,  projectId, invDate,  invoicePeriod, isgenerate, getInvoiceType)
		begin
			@@sqmutex.synchronize do
				addInvoice(parentId, parentType,  projectId, invDate,  invoicePeriod, isgenerate, getInvoiceType)
			end
		rescue => ex
		  logger.error ex.message
		end
	end

	def saveOrderRelations
	end

	def getInvoiceHeaders
		headers = [getLabelInvNum, getDateLbl, l(:field_status), getAccountLbl]
		headers
	end

	def getInvoices(invoice)
		status = invoice.status == 'o' ? l(:label_open_issues) : l(:label_closed_issues)
		invoiceArr = [invoice.invoice_number, invoice.invoice_date, status, invoice&.parent&.name]
		invoiceArr
	end

	def getSupplierAddress(invoice)
		getMainLocation + "\n" +  getAddress
	end

	def getCustomerAddress(invoice)
		invoice.parent.name + "\n" + (invoice.parent.address.blank? ? "" : invoice.parent.address.fullAddress) + (invoice&.parent_type == 'WkAccount' ? "\n" + "GST No: " + invoice&.parent&.tax_number.to_s : "")
	end

	def getOrderContract(invoice)
	end

	def storeInvoiceItemTax(totals)
		saveInvoiceItemTax(totals)
	end

	def addDescription
		true
	end
	
	def getOrderComponetsId
		'wktime_sq_components'
	end

	def includeClosedIssues
		Setting.plugin_redmine_wktime['wktime_sales_quote_closed_issues'].present? && Setting.plugin_redmine_wktime['wktime_sales_quote_closed_issues'].to_i == 1
	end
end
