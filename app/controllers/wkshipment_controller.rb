class WkshipmentController < ApplicationController
  unloadable
before_filter :require_login

include WkcrmHelper
include WkshipmentHelper
include WkinvoiceHelper
include WkgltransactionHelper


	def index
		set_filter_session
	end

	def new
	end

	def edit
		@shipment = nil
		@shipmentItem = nil
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
		
		if !params[:new_shipment].blank? && params[:new_shipment] == "true"			
			if parentId.blank?
				flash[:error] = "Account and Contacts can't be empty."
				return redirect_to :action => 'new'
			end
			newShipment(parentId, parentType)
		end		
		editShipment
		# unless params[:is_report].blank? || !to_boolean(params[:is_report])
			# @invoiceItem = @invoiceItem.order(:project_id, :item_type)
			# render :action => 'invreport', :layout => false
		# end
		
	end
	
	def newShipment(parentId, parentType)
		@shipment = WkShipment.new(:parent_id => parentId, :parent_type => parentType)
		@shipmentItem = nil
		@inventoryItem = nil
		if !params[:populate_items].blank? && params[:populate_items] == '1' && !params[:si_id].blank?
			@shipmentItem = Array.new
			ids = params[:si_id] #params[:po_id].blank? ? params[:si_id] : params[:po_id]
			@populateItems =  WkInvoiceItem.where(" invoice_id in (#{ids}) and item_type = 'i'")
			otherCharges =  WkInvoiceItem.where(" invoice_id in (#{ids}) and item_type <> 'i'").sum('amount')
			itemCount = @populateItems.sum('quantity')
			overHeadPrice = otherCharges.to_f/itemCount.to_f
			@populateItems.each do|item|
				#shipItem = @shipment.shipment_items.new
				inventory = @shipment.inventory_items.new
				inventory.notes = item.name
				inventory.total_quantity = item.quantity
				inventory.available_quantity = item.quantity
				inventory.org_currency = item.currency
				inventory.org_cost_price = item.rate
				inventory.org_over_head_price = overHeadPrice
				inventory.org_selling_price = inventory.org_cost_price + inventory.org_over_head_price
				inventory.currency = item.currency
				inventory.cost_price = item.rate
				inventory.over_head_price = overHeadPrice
				inventory.selling_price = inventory.cost_price + inventory.over_head_price
				inventory.total_quantity = item.quantity
				inventory.status = 'o'
				#if params[:po_id].blank?
					inventory.supplier_invoice_id = item.invoice_id
				#else
					#shipItem.purchase_order_id = item.invoice_id
				#end
				@shipmentItem << inventory
			end
		else
			@shipmentItem = Array.new
			@shipmentItem << @shipment.inventory_items.new
		end
		
	end
	
	def editShipment			
		unless params[:shipment_id].blank?
			@shipment = WkShipment.find(params[:shipment_id].to_i)
			@shipmentItem = @shipment.inventory_items 
			#@invPaymentItems = @shipment.payment_items.current_items				
			#pjtList = @invoiceItem.select(:project_id).distinct
			# pjtList.each do |entry| 
				# @projectsDD << [ entry.project.name, entry.project_id ] if !entry.project_id.blank? && entry.project_id != 0  
			# end			
		end		
	end
  
	def update
		errorMsg = nil
		shipmentItem = nil
		arrId = nil
		unless params["shipment_id"].blank?
			@shipment = WkShipment.find(params["shipment_id"].to_i)
			arrId = @shipment.inventory_items.pluck(:id)
		else
			@shipment = WkShipment.new
			@shipment.shipment_type = 'I'
			@shipment.parent_id = params[:parent_id]
			@shipment.parent_type = params[:parent_type]
		end
		@shipment.shipment_date = params[:shipment_date]
		#@shipment.status = 'o'
		@shipment.serial_number = params[:serial_number]
		@shipment.save()
		totalAmount = 0
		tothash = Hash.new
		totalRow = params[:totalrow].to_i
		savedRows = 0
		deletedRows = 0
		sysCurrency = Setting.plugin_redmine_wktime['wktime_currency']
		#for i in 1..totalRow
		while savedRows < totalRow
			i = savedRows + deletedRows + 1
			if params["item_id#{i}"].blank? && params["product_id#{i}"].blank?
				deletedRows = deletedRows + 1
				next
			end
			unless params["item_id#{i}"].blank?			
				arrId.delete(params["item_id#{i}"].to_i)
				shipmentItem = WkInventoryItem.find(params["item_id#{i}"].to_i)
			else				
				shipmentItem = @shipment.inventory_items.new
			end
			shipmentItem.product_item_id = params["product_item_id#{i}"].to_i
			# shipmentItem.product_id = params["product_id#{i}"].to_i
			# shipmentItem.brand_id = params["brand_id#{i}"].to_i
			# shipmentItem.product_attribute_id = params["attribute_id#{i}"].to_i unless params["attribute_id#{i}"].blank?
			# shipmentItem.product_model_id = params["model_id#{i}"].to_i unless params["model_id#{i}"].blank?
			if sysCurrency != params["currency#{i}"]
				shipmentItem.org_currency = params["currency#{i}"]
				shipmentItem.org_cost_price = params["cost_price#{i}"]
				shipmentItem.org_over_head_price = params["over_head_price#{i}"]
				shipmentItem.org_selling_price = params["selling_price#{i}"]
			end
			shipmentItem.currency = sysCurrency
			shipmentItem.cost_price = getExchangedAmount(params["currency#{i}"], params["cost_price#{i}"]) 
			shipmentItem.over_head_price = getExchangedAmount(params["currency#{i}"], params["over_head_price#{i}"])
			shipmentItem.selling_price = getExchangedAmount(params["currency#{i}"], params["selling_price#{i}"]) 
			shipmentItem.serial_number = params["serial_number#{i}"]
			shipmentItem.notes = params["notes#{i}"]
			# shipmentItem.currency = params["currency#{i}"]
			# shipmentItem.cost_price = params["cost_price#{i}"]
			# shipmentItem.over_head_price = params["over_head_price#{i}"]
			# shipmentItem.selling_price = params["selling_price#{i}"]
			# shipmentItem.org_currency = params["org_currency#{i}"]
			# shipmentItem.org_cost_price = params["org_cost_price#{i}"]
			# shipmentItem.org_over_head_price = params["org_over_head_price#{i}"]
			# shipmentItem.org_selling_price = params["org_selling_price#{i}"]
			shipmentItem.total_quantity = params["total_quantity#{i}"]
			shipmentItem.available_quantity = params["total_quantity#{i}"]
			shipmentItem.status = 'o'
			shipmentItem.uom_id = params["uom_id#{i}"].to_i unless params["uom_id#{i}"].blank?
			shipmentItem.location_id = params["location_id#{i}"].to_i unless params["location_id#{i}"].blank?
			shipmentItem.save()
			savedRows = savedRows + 1
		end
		
		if !arrId.blank?
			WkInventoryItem.delete_all(:id => arrId)
		end
		
		unless @shipment.id.blank?
			totalAmount = @shipment.inventory_items.sum('total_quantity*(cost_price+selling_price)')
			if totalAmount > 0 && autoPostGL('inventory')
				transId = @shipment.gl_transaction.blank? ? nil : @shipment.gl_transaction.id
				glTransaction = postToGlTransaction('inventory', transId, @shipment.shipment_date, totalAmount, @shipment.inventory_items[0].currency, nil, nil)
				unless glTransaction.blank?
					@shipment.gl_transaction_id = glTransaction.id
					@shipment.save
				end				
			end
		end
		
		if errorMsg.nil? 
			redirect_to :action => 'index' , :tab => controller_name
			flash[:notice] = l(:notice_successful_update)
	   else
			flash[:error] = errorMsg
			redirect_to :action => 'edit', :shipment_id => @shipment.id
	   end
	end

	def destroy
	end   

	def set_filter_session
		if params[:searchlist].blank? && session[controller_name].nil?
			session[controller_name] = {:period_type => params[:period_type],:period => params[:period], :contact_id => params[:contact_id], :account_id => params[:account_id], :project_id => params[:project_id], :polymorphic_filter =>  params[:polymorphic_filter], :rfq_id => params[:rfq_id], :from => @from, :to => @to}
		elsif params[:searchlist] == controller_name
			session[controller_name][:period_type] = params[:period_type]
			session[controller_name][:period] = params[:period]
			session[controller_name][:from] = params[:from]
			session[controller_name][:to] = params[:to]
			session[controller_name][:contact_id] = params[:contact_id]
			session[controller_name][:project_id] = params[:project_id]
			session[controller_name][:account_id] = params[:account_id]
			session[controller_name][:polymorphic_filter] = params[:polymorphic_filter]
			session[controller_name][:rfq_id] = params[:rfq_id]
		end
		
	end

	def getOrderAccountType
		'S'
	end

	def getOrderContactType
		'SC'
	end

	def getAccountDDLbl
		l(:label_supplier_account)
	end

	def getAdditionalDD
		"wkshipment/shipmentadditionaldd"
	end
	
	def textfield_size
		6
	end
	
	def populateProductItemDD
		itemArr = ""	
		sqlCond = " product_id = #{params[:product_id].to_i}"
		productItemArr = getProductItemArr(sqlCond, false)
		productItemArr.each do |item|
			itemArr << item[1].to_s() + ',' +  item[0] + "\n"
		end
		respond_to do |format|
			format.text  { render :text => itemArr }
		end
	end
end
