class WksupplierinvoiceController < WksupplierorderentityController

  menu_item :wkrfq
	@@simutex = Mutex.new

	def newSupOrderEntity(parentId, parentType)
		super
		if params[:rfq_id].present? && ((Setting.plugin_redmine_wktime['label_create_supplier_invoice_without_purchase_order'].blank? || Setting.plugin_redmine_wktime['label_create_supplier_invoice_without_purchase_order'] == 0) && params[:po_id].blank?)
			errorMsg = ""
			errorMsg = l(:error_please_select_rfq) + " <br/>" if params[:rfq_id].blank?
			errorMsg = errorMsg + l(:error_please_select_po) + " <br/>" if params[:po_id].blank?
			flash[:error] = errorMsg
			redirect_to :action => 'new'
		else
			if(params[:po_id] != "")
				@poId =params[:po_id].to_i
			else
				@poId = ""
			end
			if !params[:populate_items].blank? && params[:populate_items] == '1'
				@invoiceItem = WkInvoiceItem.where(:invoice_id => params[:po_id].to_i)
					.select(:name, :rate, :amount, :quantity, :item_type, :currency, :project_id, :modifier_id,  :invoice_id, :original_amount, :original_currency, :product_id, :invoice_item_type, :invoice_item_id)
			end
		end
	end

	def editOrderEntity
		super
		unless params[:invoice_id].blank?
			@siObj = WkPoSupplierInvoice.find(@invoice.sup_inv_po.id) unless @invoice.blank?
		end
	end

	def saveOrderInvoice(parentId, parentType,  projectId, invDate,  invoicePeriod, isgenerate, getInvoiceType)
		begin
			@@simutex.synchronize do
				addInvoice(parentId, parentType,  projectId, invDate,  invoicePeriod, isgenerate, getInvoiceType)
			end
		rescue => ex
		  logger.error ex.message
		end
	end

	def saveOrderRelations
		savePoSupInv(params[:si_id], params[:si_inv_id], @invoice.id)
	end

	def get_rfq_po_ids
		quoteIds = ""
		rfqObj = ""
		rfqObj = WkInvoice.where(id: getInvoiceIds(params[:rfq_id].to_i, 'PO', false), parent_id: params[:parent_id].to_i, parent_type: params[:parent_type], status: 'o').order(:id)
		if !Setting.plugin_redmine_wktime['label_create_supplier_invoice_without_purchase_order'].blank? && Setting.plugin_redmine_wktime['label_create_supplier_invoice_without_purchase_order'].to_i == 1
			quoteIds << "," + "\n"
		end
		rfqObj.each do | entry|
			quoteIds <<  entry.id.to_s() + ',' + entry.invoice_number.to_s() + " - " + entry.confirm_num.to_s()  + "\n"
		end
		respond_to do |format|
			format.text  { render :plain => quoteIds }
		end
	end

	def getInvoiceType
		'SI'
	end

	def getHeaderLabel
		l(:label_supplier_invoice)
	end

	def getLabelNewInv
		l(:label_new_sup_invoice)
	end

	def getPopulateChkBox
		l(:label_populate_purchase_items)
	end

	def getItemLabel
		l(:label_si_items)
	end

	def getLabelInvNum
		l(:label_sp_number)
	end

	def getDateLbl
		l(:label_sp_date)
	end

	def getAdditionalDD
		"wksupplierinvoice/siadditionaldd"
	end

	def editInvNumber
		true
	end

	def getOrderNumberPrefix
		'wktime_si_no_prefix'
	end

	def getNewHeaderLbl
		l(:label_new_sup_invoice)
	end

	def getOrderContract(invoice)
		contractStr = nil
		po = invoice.sup_inv_po.purchase_order
		unless po.blank?
			contractStr = po.invoice_number + " - " + po.invoice_date.to_formatted_s(:long)
		end
		contractStr
	end

	def getOrderComponetsId
		'wktime_si_components'
	end

	def isInvPaymentLink
		true
	end

	def getAutoPostModule
		'supplier_invoice'
	end

	def postableInvoice
		true
	end

	def addAdditionalTax
		false
	end

	def storeInvoiceItemTax(totals)
		saveInvoiceItemTax(totals)
	end

	# When Saving SI, update Purchase Order status
	def update_status
		invoices = @invoice&.sup_inv_po&.purchase_order&.supplier_invoices
		po = @invoice&.sup_inv_po&.purchase_order
		if po.present?
			inv_quantity = {po.id => 0}
			po_quantity = 0
			(invoices || {}).each do |invoice|
				invoice.invoice_items.each do |inv_item|
					if inv_item.invoice_item_id.blank? && ["i", "e"].include?(inv_item.item_type)
						inv_quantity[po.id] += (inv_item.quantity || 0)
					elsif ["i", "e"].include?(inv_item.item_type)
						inv_quantity[inv_item.invoice_item_id] ||= 0
						inv_quantity[inv_item.invoice_item_id] += inv_item.quantity
					end
				end
			end
			status = po.status
			(po.invoice_items || {}).each do |po_item|
				if inv_quantity[po_item.invoice_item_id].present? && ["i", "e"].include?(po_item.item_type)
					status = inv_quantity[po_item.invoice_item_id] == po_item.quantity ? "c" : "o"
					break if status == "o"
				elsif ["i", "e"].include?(po_item.item_type)
					po_quantity += po_item.quantity
				end
			end
			status = po_quantity == inv_quantity[po.id] ? "c" : "o"
			po.status = status
			po.save()
		end
	end

	def loadPurchaseDD
		true
	end
end
