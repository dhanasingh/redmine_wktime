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

class WkorderentityController < WkbillingController
  unloadable
	include WktimeHelper
	include WkinvoiceHelper
	include WkbillingHelper
	include WkorderentityHelper
	include WkreportHelper
	include WkgltransactionHelper

	def index
		sort_init 'invoice_date', 'desc'

		sort_update 'invoice_number' => "invoice_number",
					'invoice_date' => "invoice_date",
					'status' => "wk_invoices.status",
					'name' => "CASE WHEN wk_invoices.parent_type = 'WkAccount' THEN a.name ELSE CONCAT(c.first_name, c.last_name) END",
					'start_date' => "start_date",
					'end_date' => "end_date",
					'amount' => "amount",
					'original_amount' => "original_amt",
					'quantity' => "quantity",
					'modified' =>  "CONCAT(users.firstname, users.lastname)"

		@projects = nil
		errorMsg = nil
		@previewBilling = false
		set_filter_session
		retrieve_date_range
		sqlwhere = ""
		filter_type = session[controller_name].try(:[], :polymorphic_filter)
		contact_id = session[controller_name].try(:[], :contact_id)
		account_id = session[controller_name].try(:[], :account_id)
		projectId	= session[controller_name].try(:[], :project_id)
		rfqId	= session[controller_name].try(:[], :rfq_id)
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

		if (!params[:preview_billing].blank? && params[:preview_billing] == "true") ||
		   (!params[:generate].blank? && params[:generate] == "true")
			if !projectId.blank? && projectId.to_i != 0
				sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
				sqlwhere = sqlwhere + " project_id = '#{projectId}' "
			end
			if filter_type == '2'  || filter_type == '3'
				accProjects = WkAccountProject.where(sqlwhere).order(:parent_type, :parent_id)
				# previewBilling(accProjects)
				# accProjects.find_each do |accProj|
				   # errorMsg = generateInvoices(accProj, projectId, @to + 1, [@from, @to]) unless params[:generate].blank? || !to_boolean(params[:generate])#accProj.parent_id,accProj.parent_type

				# end
			end

			if filter_type == '1'
				if  projectId.blank?
					accProjects = WkAccountProject.all.order(:parent_type, :parent_id)
				else
					accProjects = WkAccountProject.where(project_id: projectId).order(:parent_type, :parent_id)
				end
				# previewBilling(accProjects)
				# accProjects.each do |accProj|
				   # errorMsg = generateInvoices(accProj, projectId, @to + 1, [@from, @to]) unless params[:generate].blank? || !to_boolean(params[:generate])

				# end
			end
			invoiceFreq = getInvFreqAndFreqStart
			invIntervals = getIntervals(@from, @to, invoiceFreq["frequency"], invoiceFreq["start"], true, false)
			@firstInterval = invIntervals[0]
			previewBilling(accProjects, @from, @to)
			invIntervals.each do |interval|
				accProjects.find_each do |accProj|
				   errorMsg = generateInvoices(accProj, projectId, interval[1] + 1, interval) unless params[:generate].blank? || !to_boolean(params[:generate])#accProj.parent_id,accProj.parent_type

				end
			end
			unless params[:generate].blank? || !to_boolean(params[:generate])
				if errorMsg.blank?
					redirect_to :action => 'index' , :tab => controller_name
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
			end
		else
			sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " invoice_type = '#{getInvoiceType}'"
			if !@from.blank? && !@to.blank?
				sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
				sqlwhere = sqlwhere + " invoice_date between '#{@from}' and '#{@to}'  "
			end

			invEntries = WkInvoice.where(sqlwhere)

			if !projectId.blank? && projectId.to_i != 0
				invEntries = invEntries.where( :wk_invoice_items => { :project_id => projectId })
			end

			if !rfqId.blank? && rfqId.to_i != 0
				invIds = getInvoiceIds(rfqId, getInvoiceType, false)
				invEntries = invEntries.where( :id => invIds)
			end
			invEntries = invEntries.joins("LEFT JOIN wk_invoice_items ON wk_invoice_items.invoice_id = wk_invoices.id
				LEFT JOIN (SELECT id, firstname, lastname FROM users) AS users ON wk_invoices.modifier_id = users.id
				LEFT JOIN wk_accounts a on (wk_invoices.parent_type = 'WkAccount' and wk_invoices.parent_id = a.id)
				LEFT JOIN wk_crm_contacts c on (wk_invoices.parent_type = 'WkCrmContact' and wk_invoices.parent_id = c.id)
				").group("wk_invoices.id, CASE WHEN wk_invoices.parent_type = 'WkAccount' THEN a.name ELSE CONCAT(c.first_name, c.last_name) END,
				CONCAT(users.firstname, users.lastname), wk_invoices.status, wk_invoices.invoice_number, wk_invoices.start_date, wk_invoices.end_date, wk_invoices.invoice_date, wk_invoices.closed_on, wk_invoices.modifier_id, wk_invoices.gl_transaction_id, wk_invoices.parent_id, wk_invoices.invoice_type, wk_invoices.invoice_num_key, wk_invoices.created_at, wk_invoices.updated_at,wk_invoices.parent_type ")
				.select("wk_invoices.*, SUM(wk_invoice_items.quantity) AS quantity, SUM(wk_invoice_items.amount) AS amount, SUM(wk_invoice_items.original_amount)
				 AS original_amt")
			invEntries =  invEntries.reorder(sort_clause)
			respond_to do |format|
				format.html do
					formPagination(invEntries)
					unless @previewBilling
						amounts = @invoiceEntries.reorder(["wk_invoices.id ASC"]).pluck("SUM(wk_invoice_items.amount)")
						@totalInvAmt = amounts.compact.inject(0, :+)
					end
				  render :layout => !request.xhr?
				end
				format.api do
					@invoiceEntries = invEntries
				end
				format.csv do
					headers = { invoice_number: getLabelInvNum, name: l(:field_name), project: l(:label_project), status: l(:field_status), inv_date: getDateLbl, start_date: l(:field_start_date), end_date: l(:label_end_date), quantity: l(:field_quantity), original_amount: l(:field_original_amount), amount: l(:field_amount), modified: l(:field_status_modified_by) }
					data = invEntries.map do |e|
						status = e.status == 'o' ? 'open' : 'closed'
						inv_items = e.invoice_items
						{ invoice_number: e&.invoice_number, name: e.parent.name, project: (inv_items&.first&.project&.name || ''), status: status, inv_date: e.invoice_date,  start_date: e.start_date, end_date: e.end_date, quantity: inv_items.sum(:quantity).round(2), original_amount: (inv_items&.first&.original_currency || '')+" "+inv_items.sum(:original_amount).round(2).to_s, amount: (inv_items&.first&.currency || '')+" "+inv_items.sum(:amount).round(2).to_s, modified: e&.modifier&.name }
					end
					respond_to do |format|
						format.csv {
							send_data(csv_export({headers: headers, data: data}), type: 'text/csv; header=present', filename: "#{getHeaderLabel}.csv")
						}
					end
				end
			end
		end
	end

	def edit
		@invoice = nil
		@invoiceItem = nil
		@projectsDD = Array.new
		@productItemsDD = getproductItems
    @currency = nil
		@preBilling = false
		@rfgQuoteEntry = nil
		@rfqObj = nil
		@poObj = nil
		@siObj = nil
		@preBilling = to_boolean(params[:preview_billing]) unless params[:preview_billing].blank?
		@listKey = 0
		@invList = Hash.new{|hsh,key| hsh[key] = {} }
		parentType = ""
		parentId = ""
		filter_type = params[:polymorphic_filter]
		contact_id = params[:polymorphic_filter]
		account_id = params[:polymorphic_filter]
		if filter_type == '2' && !contact_id.blank?
			parentType = 'WkCrmContact'
			parentId = 	params[:contact_id]
		elsif filter_type == '2' && contact_id.blank?
			parentType = 'WkCrmContact'
		end

		if filter_type == '3' && !account_id.blank?
			parentType =  'WkAccount'
			parentId = 	params[:account_id]
		elsif filter_type == '3' && account_id.blank?
			parentType =  'WkAccount'
		end

		if parentId.blank? && parentType.blank?
			parentType = params[:related_to]
			parentId = params[:related_parent]
		end

		if !params[:new_invoice].blank? && params[:new_invoice] == "true"
			if parentId.blank?
				flash[:error] = "Account and Contacts can't be empty."
				return redirect_to :action => 'new'
			end
			newOrderEntity(parentId, parentType)
		end
		editOrderEntity
		if params[:loadUnBilled]
			setUnbilledParams
			newOrderEntity(params[:related_parent], params[:related_to])
		end
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

	def newOrderEntity(parentId, parentType)
	end

	def editOrderEntity
		unless params[:invoice_id].blank?
			@invoice = WkInvoice.find(params[:invoice_id].to_i)
			@invoiceItem = @invoice.invoice_items
			@invPaymentItems = @invoice.payment_items.current_items
			pjtList = @invoiceItem.select(:project_id).distinct
			pjtList.each do |entry|
				@projectsDD << [ entry.project.name, entry.project_id ] if !entry.project_id.blank? && entry.project_id != 0
			end
		end
	end

	def setTempEntity(startDate, endDate, relatedParent, relatedTo, populatedItems, projectId)
		@itemCount = 0
		@invItems = Hash.new{|hsh,key| hsh[key] = {} }
		@invoice = WkInvoice.new
		@invoice.invoice_date = Date.today
		@invoice.id = ""
		@invoice.invoice_number = ""
		@invoice.start_date = startDate
		@invoice.end_date = endDate
		@invoice.status = 'o'
		@invoice.modifier_id = User.current.id
		@invoice.parent_id = relatedParent
		@invoice.parent_type = relatedTo
	end

	def new

	end

	def update
		isEditable = true
		status_changed = true
		unless params["invoice_id"].blank?
			issuedCrCount = WkInvoiceItem.where(:credit_invoice_id => params["invoice_id"].to_i).count
			invoicePayCount = WkPaymentItem.where(:invoice_id => params["invoice_id"].to_i).count
			isEditable = false if issuedCrCount>0 || invoicePayCount>0
			status_changed = params[:field_status] == params[:saved_field_status]
		end
		if api_request?
			row_index =0
			params['invoiceItems'].each do |index, data|
				if data['hd_item_type'] != 't' && data['hd_item_type'] != 'r'
					row_index = row_index+1
					data.each do | item |
						params[item.first + '_' +(row_index).to_s] = item.last
					end
				end
			end
			params['totalrow'] = row_index
		end
		errorMsg = nil
		invoiceItem = nil
		if isEditable
			arrId = []
			unless params["invoice_id"].blank?
				@invoice = WkInvoice.find(params["invoice_id"].to_i)
				@invoice.invoice_date = params[:inv_date]
				arrId = @invoice.invoice_items.pluck(:id)
			else
				@invoice = WkInvoice.new
				invoicePeriod = getInvoicePeriod(params[:inv_start_date], params[:inv_end_date])#[params[:inv_start_date], params[:inv_end_date]]
				saveOrderInvoice(params[:parent_id], params[:parent_type],  params[:project_id_1],params[:inv_date],  invoicePeriod, false, getInvoiceType)

			end
			@invoice.status = params[:field_status] unless params[:field_status].blank?
			unless params[:inv_number].blank?
				@invoice.invoice_number = params[:inv_number]
			end
			if @invoice.status_changed?
				@invoice.closed_on = Time.now
			end
			@invoice.save()
			totalAmount = 0
			total_amounts = Hash.new
			totalRow = params[:totalrow].to_i
			savedRows = 0
			deletedRows = 0
			productArr = Array.new
			@matterialVal = Hash.new{|hsh,key| hsh[key] = {} }
			@totalMatterialAmount = 0.00

			while savedRows < totalRow
				i = savedRows + deletedRows + 1
				if params["item_id_#{i}"].blank? && params["quantity_#{i}"].blank?
					deletedRows = deletedRows + 1
					next
				end
				crInvoiceId = nil
				crPaymentId = nil
				if params["creditfrominvoice_#{i}"] == "true"
					crInvoiceId = params["entry_id_#{i}"].to_i
				elsif params["creditfrominvoice_#{i}"] == "false"
					crPaymentId = params["entry_id_#{i}"].to_i
				end
				pjtId = params["project_id_#{i}"] if !params["project_id_#{i}"].blank?
				itemType = params["item_type_#{i}"].blank? ? params["hd_item_type_#{i}"]  : params["item_type_#{i}"]

				invoice_item_id = (params["invoice_item_id_#{i}"]).split(",").last
				invoice_item_id = invoice_item_id.present? ? invoice_item_id.to_i : nil
				product_id = params["product_id_#{i}"].present? ? params["product_id_#{i}"] : (params["invoice_item_id_#{i}"]).split(",").first
				product_id = product_id.present? ? product_id.to_i : nil
				unless params["item_id_#{i}"].blank?
					arrId.delete(params["item_id_#{i}"].to_i)
					invoiceItem = WkInvoiceItem.find(params["item_id_#{i}"].to_i)
					org_amount = params["rate_#{i}"].to_f * params["quantity_#{i}"].to_f
					updatedItem = updateInvoiceItem(invoiceItem, pjtId,  params["name_#{i}"], params["rate_#{i}"].to_f, params["quantity_#{i}"].to_f, invoiceItem.original_currency, itemType, org_amount, crInvoiceId, crPaymentId, product_id, params["invoice_item_type_#{i}"], invoice_item_id)
				else
					invoiceItem = @invoice.invoice_items.new
					org_amount = params["rate_#{i}"].to_f * params["quantity_#{i}"].to_f
					updatedItem = updateInvoiceItem(invoiceItem, pjtId, params["name_#{i}"], params["rate_#{i}"].to_f, params["quantity_#{i}"].to_f, params["original_currency_#{i}"], itemType, org_amount, crInvoiceId, crPaymentId, product_id, params["invoice_item_type_#{i}"], invoice_item_id)
				end
				if !params[:populate_unbilled].blank? && params[:populate_unbilled] == "true" && params[:creditfrominvoice].blank? && !params["entry_id_#{i}"].blank?
					accProject = WkAccountProject.where(:project_id => pjtId)
					if accProject[0].billing_type == 'TM'
						idArr = params["entry_id_#{i}"].split(' ')
						idArr.each do | id |
							timeEntry = TimeEntry.find(id)
							updateBilledEntry(timeEntry, updatedItem.id)
						end
					elsif !params["entry_id_#{i}"].blank?
						scheduledEntry = WkBillingSchedule.find(params["entry_id_#{i}"].to_i)
						scheduledEntry.invoice_id = @invoice.id
						scheduledEntry.save()
					end
				end
				unless params["material_id_#{i}"].blank?
					matterialEntry = WkMaterialEntry.find(params["material_id_#{i}"].to_i)
					updateBilledEntry(matterialEntry, updatedItem.id)
				end

				if updatedItem.product_id.present?
					# set Product Totals
					total_amounts["product"] = set_product_total(total_amounts["product"], updatedItem)
				elsif updatedItem.project_id.present?
					# set project Totals
					total_amounts["project"] = set_project_total(total_amounts["project"], updatedItem)
				end
				savedRows = savedRows + 1
			end

			unless params["material_id_#{i}"].blank?
				matterialEntry = WkMaterialEntry.find(params["material_id_#{i}"].to_i)
				updateBilledEntry(matterialEntry, updatedItem.id)
			end

			# Calculate & Save Tax, Combine same project & product taxes
			storeInvoiceItemTax(total_amounts)

			if !arrId.blank?
				deleteBilledEntries(arrId)
				WkInvoiceItem.where(:id => arrId).delete_all
			end

			unless @invoice.id.blank?
				saveOrderRelations
				WkInvoice.send_notification(@invoice) if params[:invoice_id].blank?
				totalAmount = @invoice.invoice_items.sum(:original_amount)
				invoiceAmount = @invoice.invoice_items.where.not(:item_type => 'm').sum(:original_amount)

				moduleAmtHash = {'inventory' => [nil, totalAmount.round - invoiceAmount.round], getAutoPostModule => [totalAmount.round, invoiceAmount.round]}
				inverseModuleArr = ['inventory']
				transAmountArr = getTransAmountArr(moduleAmtHash, inverseModuleArr)
				if isChecked("invoice_auto_round_gl") && (totalAmount.round - totalAmount) != 0
					addRoundInvItem(totalAmount)
				end
				if totalAmount > 0 && autoPostGL(getAutoPostModule) && postableInvoice
					transId = @invoice.gl_transaction.blank? ? nil : @invoice.gl_transaction.id
					glTransaction = postToGlTransaction(getAutoPostModule, transId, @invoice.invoice_date, transAmountArr, @invoice.invoice_items[0].original_currency, invoiceDesc(@invoice,invoiceAmount), nil)
					unless glTransaction.blank?
						@invoice.gl_transaction_id = glTransaction.id
						@invoice.save
					end
				end
			end
		elsif !isEditable && !status_changed && params["invoice_id"].present?
			@invoice = WkInvoice.find(params["invoice_id"].to_i)
			@invoice.invoice_date = params[:inv_date]
			unless params[:inv_number].blank?
				@invoice.invoice_number = params[:inv_number]
			end
			@invoice.status = params[:field_status] unless params[:field_status].blank?
			@invoice.save
		end

		respond_to do |format|
			format.html {
				if errorMsg.nil?
					redirect_to :action => 'index' , :tab => controller_name
					flash[:notice] = l(:notice_successful_update)
				else
						flash[:error] = errorMsg
						redirect_to :action => 'edit', :invoice_id => @invoice.id
				end
			}
			format.api{
				if errorMsg.blank?
					render :plain => errorMsg, :layout => nil
				else
					@error_messages = errorMsg.split('\n')
					render :template => 'common/error_messages.api', :status => :unprocessable_entity, :layout => nil
				end
			}
		end
	end

	def getHeaderLabel
		l(:label_invoice)
	end

	def saveOrderInvoice(parentId, parentType,  projectId, invDate,  invoicePeriod, isgenerate, getInvoiceType)
	end

	def saveOrderRelations
	end

	def deleteBilledEntries(invItemIdsArr)
	end

	def getInvoicePeriod(startDate, endDate)
		[startDate, endDate]
	end

	def getOrderContract(invoice)
		contractStr = nil
		accContract = invoice.parent.contract(@invoiceItem[0].project, invoice.end_date)
		unless accContract.blank?
			contractStr = accContract.contract_number + " - " + accContract.start_date.to_formatted_s(:long)
		end
		contractStr
	end

	def destroy
		invoice = WkInvoice.find(params[:invoice_id].to_i)#.destroy
		deleteBilledEntries(invoice.invoice_items.pluck(:id))
		if invoice.destroy
			flash[:notice] = l(:notice_successful_delete)
		else
			flash[:error] = invoice.errors.full_messages.join("<br>")
		end
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end

		def set_filter_session
			filters = [:period_type, :period, :from, :to, :contact_id, :account_id, :project_id, :polymorphic_filter, :rfq_id]
			super(filters, {:from => @from, :to => @to})
    end


	def formPagination(entries)
		@entry_count = entries.length
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

	def getOrderComponetsId
		'wktime_invoice_components'
	end

	def getSupplierAddress(invoice)
		getMainLocation + "\n" +  getAddress
	end

	def getCustomerAddress(invoice)
		invoice.parent.name + "\n" + (invoice.parent.address.blank? ? "" : invoice.parent.address.fullAddress)
	end

	def getAutoPostModule
	end

	def postableInvoice
		false
	end

	def deletePermission
		false
	end

	def addMaterialType
		false
	end

	def addAssetType
		false
	end

	def getAccountLbl
		l(:field_account)
	end

	def showProjectDD
		false
	end

	def getInvProj
		@projectsDD = Array.new
		@invList = Hash.new{|hsh,key| hsh[key] = {} }
		if !params[:new_invoice].blank? && params[:new_invoice] == "true"
			newOrderEntity(params[:parent_id], params[:parent_type])
		end
		editOrderEntity
		invProj = []
		invProj = @projectsDD.map { |name, id| { value: id, label:  name }} if @projectsDD.present?
		render json: invProj
	end

	def export
		unless params[:invoice_id].blank?
			@projectsDD = Array.new
			editOrderEntity
		end
		respond_to do |format|
			format.pdf {
				send_data(invoice_to_pdf(@invoice), type: 'application/pdf', filename: "#{getHeaderLabel}.pdf")
			}
			format.csv {
				send_data(invoice_to_csv(@invoice), type: 'text/csv; header=present', filename: "#{getHeaderLabel}.csv")
			}
		end
	end

	def invoice_to_pdf(invoice)
		title = getHeaderLabel
		@invoiceItem = invoice.invoice_items
		projIDs = @invoiceItem.where(product_id: nil).where.not(:item_type => 'r').pluck(:project_id).uniq()
		prodIDs = @invoiceItem.where.not(product_id: nil).where.not(:item_type => 'r').pluck(:product_id).uniq()
		projectID =  @invoiceItem.collect{|i| i.project_id}.uniq
		invoiceComp = getInvoiceComponents(invoice.parent_id, invoice.parent_type, projectID, getOrderComponetsId )
		pdf = ITCPDF.new(current_language)
		pdf.SetTitle(title)
		pdf.add_page
		page_width    = pdf.get_page_width
		left_margin   = pdf.get_original_margins['left']
		right_margin  = pdf.get_original_margins['right']
		table_width = page_width - right_margin - left_margin
		pdf.SetFontStyle('B',13)
		pdf.RDMMultiCell(table_width, 5, title, 0, 'C')

		logo = WkLocation.getMainLogo()
		if logo.present?
			pdf.Image(logo.diskfile.to_s, page_width-50, 15, 30, 25)
		end
		pdf.ln(25)

		invoiceDetails = [l(:label_name_address_of,l(:label_supplier)), l(:label_name_address_of,l(:label_customer)),
			getLabelInvNum, getDateLbl ]
		width = table_width/invoiceDetails.size
		invoiceDetails.each do |detail|
			pdf.SetFontStyle('',10)
			pdf.set_fill_color(230, 230, 230)
			pdf.RDMMultiCell(width, 15, detail, 1, 'C', 1, 0)
		end
		pdf.ln(15)
		pdf.set_fill_color(255, 255, 255)
		pdf.RDMMultiCell(width, 30, getSupplierAddress(invoice), 1, 'L', 0, 0)
		pdf.RDMMultiCell(width, 30, getCustomerAddress(invoice), 1, 'L', 0, 0)
		pdf.RDMMultiCell(width, 30, invoice.invoice_number, 1, 'L', 0, 0)
		pdf.RDMMultiCell(width, 30, format_date(invoice.invoice_date), 1, 'L', 0, 0)
		pdf.ln(30)

		pdf.SetFontStyle('B',10)
		pdf.ln
		pdf.RDMCell(130, 5, l(:label_cntrt_purchase_work_order), 1, 0, '', 1)
		pdf.RDMCell(table_width - 130, 5, l(:label_period), 1, 0, '', 1)
		pdf.ln
		pdf.SetFontStyle('',10)
		pdf.RDMMultiCell(130, 10, getOrderContract(invoice) || '', 1, 'L', 0, 0)
		pdf.RDMMultiCell(table_width - 130, 10, format_date(invoice.start_date) + ' to ' + format_date(invoice.end_date), 1, 'L', 0, 0)

		pdf.ln(10)
		pdf.SetFontStyle('B',13)
		pdf.RDMCell(50, 15, getItemLabel)
		pdf.ln
		pdf.SetFontStyle('',10)
		pdf.set_fill_color(230, 230, 230)
		pdf.RDMCell(80, 10, l(:label_invoice_name), 1, 0, 'C', 1)
		headerList = [l(:label_billing_type), l(:label_rate), l(:field_quantity), l(:field_currency), l(:field_amount)]
		columnWidth = (table_width - 80)/headerList.size
		headerList.each do |header|
			pdf.RDMCell(columnWidth, 10, header, 1, 0, 'C', 1)
		end
		pdf.set_fill_color(255, 255, 255)
		(projIDs || []).each do |id|
			invoiceItems = @invoiceItem.where(product_id: nil, project_id: id).where.not(:item_type => 'r').order(:item_type)
			invoiceItemDetail(pdf, invoice, invoiceItems, columnWidth)
		end
		(prodIDs || []).each do |id|
			invoiceItems = @invoiceItem.where(product_id: id).where.not(:item_type => 'r').order(:item_type)
			invoiceItemDetail(pdf, invoice, invoiceItems, columnWidth)
		end
		roundoffItem = @invoiceItem.where(:item_type => 'r')
		unless roundoffItem.blank?
			roundoffItem.each do |entry|
				listItem(pdf, entry, columnWidth)
			end
		end
		listTotal(pdf, columnWidth, @invoiceItem, l(:label_grand_total))
		pdf.ln(5)
		pdf.SetFontStyle('B',10)
		pdf.RDMCell(40, 5, l(:label_amount_in_words) + "  :  ", 1)
		pdf.SetFontStyle('',10)
		pdf.RDMCell(table_width - 40, 5, numberInWords(@invoiceItem.sum(:original_amount)) + " " + l(:label_only), 1)
		pdf.ln
		if invoiceComp.present?
			invoiceComp.each do |comp|
				pdf.RDMCell(100, 5, comp[:name], 1, 0, '', 1)
				pdf.RDMCell(table_width - 100, 5, comp[:value], 1, 0, '', 1)
				pdf.ln
			end
		end
		pdf.ln(15)
		pdf.SetFontStyle('B',10)
		pdf.RDMCell(30, 5, l(:label_place) + "  :  ", 0)
		pdf.ln
		pdf.RDMCell(30, 5, l(:label_date) + "  :  ", 0)
		pdf.RDMCell(table_width-30, 5, l(:label_authorized_signatory), 0, 0, 'R')
		pdf.Output
	end

	def invoiceItemDetail(pdf, invoice, invoice_items, columnWidth)
		lastItemType = nil
		lastProjectId = nil
		invoice_items.each do | entry |
			if entry.item_type != 'r'
				height = pdf.get_string_height(80, entry.name)
				pdf.SetFontStyle('',10)

				if !lastItemType.blank? && entry.item_type != lastItemType && lastProjectId == entry.project_id && lastItemType == 'C'
					pdf.SetFontStyle('B',10)
					pdf.RDMMultiCell(80, height, '', 1, 'L', 0, 0)
					pdf.RDMCell(columnWidth, height, '', 1, 0, 'L')
					pdf.set_fill_color(230, 230, 230)
					pdf.RDMCell(columnWidth, height, l(:label_sub_total), 1, 0, 'R')
					pdf.RDMCell(columnWidth, height, invoice_items.where(:project_id => lastProjectId, :item_type => 'i').sum(:quantity).round(2).to_s, 1, 0, 'R')
					pdf.RDMCell(columnWidth, height, entry.original_currency.to_s, 1, 0, 'R')
					pdf.RDMCell(columnWidth, height, invoice_items.where(:project_id => lastProjectId, :item_type => 'i').sum(:original_amount).round(2).to_s, 1, 0, 'R')
					pdf.set_fill_color(255, 255, 255)
				end
	
				if !lastProjectId.blank? && lastProjectId != entry.project_id
					pdf.SetFontStyle('B',10)
					pdf.RDMMultiCell(80, height, '', 1, 'L', 0, 0)
					pdf.RDMCell(columnWidth, height, '', 1, 0, 'L')
					pdf.set_fill_color(230, 230, 230)
					pdf.RDMCell(columnWidth, height, l(:label_total), 1, 0, 'R')
					pdf.RDMCell(columnWidth, height, invoice_items.where(:project_id => lastProjectId).where.not(:item_type => 'r').sum(:quantity).round(2).to_s, 1, 0, 'R')
					pdf.RDMCell(columnWidth, height, entry.original_currency.to_s, 1, 0, 'R')
					pdf.RDMCell(columnWidth, height, invoice_items.where(:project_id => lastProjectId).where.not(:item_type => 'r').sum(:original_amount).round(2).to_s, 1, 0, 'R')
					pdf.set_fill_color(255, 255, 255)
				end

				item_type = (entry.item_type == 'i' && invoice.invoice_type == 'I') && l(:field_hours) || entry.item_type == 'm' && l(:label_material) ||
							entry.item_type == 'a' && l(:label_rental) || entry.item_type == 'e' && l(:label_expenses) ||  ""
				rate = entry.rate.present? ? entry.rate.round(2).to_s + (entry.item_type == 'i' || entry.item_type == 'c' || entry.item_type == 'm' || entry.item_type == 'a' || entry.item_type == 'e' ? '' : ( addAdditionalTax ? '' : "%")) : ''

				pdf.SetFontStyle('',10)
				pdf.ln
				pdf.RDMMultiCell(80, height, entry.name, 1, 'L', 0, 0)
				pdf.RDMCell(columnWidth, height, item_type.to_s, 1, 0, 'L')
				pdf.RDMCell(columnWidth, height, rate.to_s, 1, 0, 'R')
				pdf.RDMCell(columnWidth, height, entry&.quantity.present? ? entry&.quantity.round(2).to_s : '', 1, 0, 'R')
				pdf.RDMCell(columnWidth, height, entry&.original_currency.to_s, 1, 0, 'R')
				pdf.RDMCell(columnWidth, height, entry&.original_amount.present? ? entry&.original_amount.round(2).to_s : '', 1, 0, 'R')	
			end
	
			lastItemType = entry.item_type
			lastProjectId = entry.project_id
		end

		pdf.ln
		pdf.SetFontStyle('B',10)
		pdf.RDMCell(80, 5, '', 0, 0, 'L')
		pdf.RDMCell(columnWidth, 5, '', 0, 0, 'L')
		pdf.set_fill_color(230, 230, 230)
		pdf.RDMCell(columnWidth, 5, l(:label_total), 1, 0, 'C',1)
		pdf.RDMCell(columnWidth, 5, invoice_items.where(:project_id => lastProjectId).where.not(:item_type => 'r').sum(:quantity).round(2).to_s, 1, 0, 'R',1)
		pdf.RDMCell(columnWidth, 5, invoice_items[0].original_currency.to_s, 1, 0, 'R',1)
		pdf.RDMCell(columnWidth, 5, invoice_items.where(:project_id => lastProjectId).where.not(:item_type => 'r').sum(:original_amount).round(2).to_s, 1, 0, 'R',1)
		pdf.set_fill_color(255, 255, 255)	
	end

	def listItem(pdf, entry, columnWidth)
		height = pdf.get_string_height(80, entry.name)
		pdf.SetFontStyle('',10)
		pdf.ln
		pdf.RDMMultiCell(80, height, entry.name, 1, 'L', 0, 0)
		pdf.RDMCell(columnWidth, height, getInvoiceItemType(entry.item_type), 1, 0, 'L')
		pdf.RDMCell(columnWidth, height, entry.item_type == 't' ? entry.rate.to_s + "%" : entry.rate.to_s, 1, 0, 'R')
		pdf.RDMCell(columnWidth, height, entry.quantity.to_s, 1, 0, 'R')
		pdf.RDMCell(columnWidth, height, entry.original_currency.to_s, 1, 0, 'R')
		pdf.RDMCell(columnWidth, height, entry.original_amount.to_s, 1, 0, 'R')
	end

	def listTotal(pdf, columnWidth, invoice, label)
		pdf.ln
		pdf.SetFontStyle('B',10)
		pdf.RDMCell(80, 5, '', 0, 0, 'L')
		pdf.RDMCell(columnWidth, 5, '', 0, 0, 'L')
		pdf.set_fill_color(230, 230, 230)
		pdf.RDMCell(columnWidth, 5, label, 1, 0, 'C',1)
		pdf.RDMCell(columnWidth, 5, invoice.sum(:quantity).round(2).to_s, 1, 0, 'R',1)
		pdf.RDMCell(columnWidth, 5, invoice.first.original_currency.to_s, 1, 0, 'R',1)
		pdf.RDMCell(columnWidth, 5, invoice.sum(:original_amount).round(2).to_s, 1, 0, 'R',1)
		pdf.set_fill_color(255, 255, 255)
	end

	def getInvoiceItemType(type)
		itemtype  = ''
		case(type)
		when 'i'
			itemtype = l(:field_hours)
		when 'c'
			itemtype = l(:label_credit)
		when 'm'
			itemtype = l(:label_material)
		when 't'
			itemtype = l(:label_tax)
		when 'a'
			itemtype = l(:label_rental)
		when 'e'
			itemtype = l(:label_expenses)
		else
			itemtype = '';
		end
	end

	def setUnbilledParams
		accPjt = WkAccountProject.getAccProj(@invoice.parent_id, @invoice.parent_type)
		params[:new_invoice] = true
		params[:populate_items] = '1'
		params[:preview_billing] = true
		params[:related_to] = @invoice.parent_type
		params[:related_parent] = @invoice.parent_id
		params[:start_date] = @invoice.start_date
		params[:end_date] = @invoice.end_date
		params[:project_id] = accPjt.present? && isAccountBilling(accPjt[0]) ? '0' : @invoiceItem.first.project_id
	end

	def exportXml
		headers = { invoice_number: l(:label_invoice_number), name: l(:field_name), project: l(:label_project), status: l(:field_status), inv_date: l(:label_invoice_date), start_date: l(:field_start_date), end_date: l(:label_end_date), quantity: l(:field_quantity), original_amount: l(:field_original_amount), amount: l(:field_amount), modified: l(:field_status_modified_by) }
		data = getIndexData.map{|entry| {invoice_number: entry&.invoice_number, name: entry.parent.name, project: (entry&.invoice_items[0]&.project&.name || ''), status: (entry.status == 'o' ? 'open' : 'closed'), inv_date: entry.invoice_date,  start_date: entry.start_date, end_date: entry.end_date, quantity: entry.invoice_items.sum(:quantity), original_amount: entry.invoice_items.sum(:original_amount), amount: entry.invoice_items.sum(:amount), modified: entry&.modifier&.name } }
		respond_to do |format|
			format.csv {
				send_data(csv_export({headers: headers, data: data}), type: 'text/csv; header=present', filename: 'contact.csv')
			}
		end
	end

	def invoice_to_csv(invoice)
		decimal_separator = l(:general_csv_decimal_separator)
		export = Redmine::Export::CSV.generate do |csv|
			csv << (getInvoiceHeaders.concat(getInvoiceItemHeaders)).collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, l(:general_csv_encoding))}
			itemDetails = invoice.invoice_items.where.not(item_type: 'r').order(:item_type)
			itemDetails.each do |entry|
				invoices = getInvoices(invoice)
				invoiceItems = getInvoiceItems(entry)
				csv << invoices.concat(invoiceItems)
			end
			csv << getInvoiceTotal(itemDetails, l(:label_total))
			itemDetails = invoice.invoice_items.where(item_type: 'r').order(:item_type)
			itemDetails.each do |entry|
				invoices = getInvoices(invoice)
				invoiceItems = getInvoiceItems(entry)
				csv << invoices.concat(invoiceItems)
			end
			csv << getInvoiceTotal(invoice.invoice_items, l(:label_grand_total))
		end
		export
  end

	def getInvoiceHeaders
		headers = [getLabelInvNum, getDateLbl, l(:field_status), getAccountLbl]
		headers
	end

	def getInvoiceItemHeaders
		headers = [l(:label_invoice_name), l(:label_billing_type), l(:label_rate), l(:field_quantity), l(:field_original_amount), l(:field_amount)]
		headers
	end

	def getInvoices(invoice)
		status = invoice.status == 'o' ? l(:label_open_issues) : l(:label_closed_issues)
		invoices = [invoice.invoice_number, invoice.invoice_date, status, invoice&.parent&.name]
		invoices
	end

	def getInvoiceItems(item)
		invoiceItems = [ item.name, getInvoiceItemType(item.item_type), item.item_type == 't' ? (item.rate.to_s + "%") : item.rate.to_s, item.quantity, item.original_currency.to_s + item.original_amount.round(2).to_s, item.currency.to_s + item.amount.round(2).to_s]
		invoiceItems
	end

	def getInvoiceTotal(invoice, label)
		if controller_name == 'wkquote'
			["","","","","","","",label,invoice.sum(:quantity).to_s, invoice.first.original_currency.to_s + invoice.sum(:original_amount).to_s, invoice.first.currency.to_s + invoice.sum(:amount).to_s]
		else
			["","","","","","",label,invoice.sum(:quantity).to_s, invoice.first.original_currency.to_s + invoice.sum(:original_amount).to_s, invoice.first.currency.to_s + invoice.sum(:amount).to_s]
		end
	end

	def getproductItems
		WkProductItem.getproductItems || []
	end

	def set_product_total(total, item)
		total ||= {}
		total[item.product_id] ||= {}
		total[item.product_id][:amount] = (total[item.product_id][:amount] || 0) + item.original_amount
		total[item.product_id][:currency] = item.original_currency
		total[item.product_id][:project_id] = item.project_id || nil
		total
	end

	def set_project_total(total, item)
		total ||= {}
		total[item.project_id] ||= {}
		total[item.project_id][:amount] = (total[item.project_id][:amount] || 0) + item.original_amount
		total[item.project_id][:currency] = item.original_currency
		total
	end

	def get_product_tax
		data = WkProductItem.getProductTax(params[:product_item_id])
		render json: data
	end

	def get_project_tax
		acc_proj = WkAccountProject.getTax(params[:project_id], params[:parent_type], params[:parent_id])&.first
		taxes = acc_proj.taxes if acc_proj.present?
    data = (taxes || []).map{|t| {name: t.name, rate: t.rate_pct, project: acc_proj.project&.name, project_id: params[:project_id]}}
		render json: data
	end

	def storeInvoiceItemTax(totals)
	end
end
