class WkshipmentController < WkinventoryController
  unloadable
  menu_item :wkproduct
before_action :require_login

include WkcrmHelper
include WkshipmentHelper
include WkinvoiceHelper
include WkgltransactionHelper
include WkinventoryHelper


	def index
		sort_init 'id', 'asc'
		sort_update 'serial_number' => "#{WkShipment.table_name}.serial_number",
					'shipment_name' => "#{WkShipment.table_name}.parent_type",
					'shipment_date' => "#{WkShipment.table_name}.shipment_date"

		set_filter_session
		retrieve_date_range
		sqlwhere = " wk_shipments.shipment_type != 'N' "
		filter_type = session[controller_name].try(:[], :polymorphic_filter)
		contact_id = session[controller_name].try(:[], :contact_id)
		account_id = session[controller_name].try(:[], :account_id)
		projectId =session[controller_name].try(:[], :project_id)
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
		
		unless parentId.blank? 
			sqlwhere = sqlwhere + " and wk_shipments.parent_id = '#{parentId}' "
		end
		
		unless parentType.blank?
			sqlwhere = sqlwhere + " and wk_shipments.parent_type = '#{parentType}'  "
		end
		
		if !@from.blank? && !@to.blank?	
			sqlwhere = sqlwhere + " and wk_shipments.shipment_date between '#{@from}' and '#{@to}'  "
		end

		shipEntries = WkShipment.includes(:inventory_items)
		projectId = nil if projectId.blank?
		shipmentIDs = projectId != 'AP' ? shipEntries.where(wk_inventory_items: {project_id: projectId}).pluck(:id) : []
		shipEntries = shipEntries.where(sqlwhere)
		shipEntries = shipEntries.where(" wk_shipments.id IN (?)", shipmentIDs) if shipmentIDs.length > 0

		formPagination(shipEntries.reorder(sort_clause))
		@totalShipAmt = @shipmentEntries.where("wk_inventory_items.parent_id is null").sum("wk_inventory_items.total_quantity*(wk_inventory_items.cost_price+wk_inventory_items.over_head_price)")
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
	end
	
	def newShipment(parentId, parentType)
		@shipment = WkShipment.new(:parent_id => parentId, :parent_type => parentType)
		@shipmentItem = nil
		@inventoryItem = nil
		if !params[:populate_items].blank? && params[:populate_items] == '1' && !params[:si_id].blank?
			@shipmentItem = Array.new
			ids = params[:si_id]
			@populateItems =  WkInvoiceItem.where(" invoice_id in (#{ids}) and item_type = 'i'")
			otherCharges =  WkInvoiceItem.where(" invoice_id in (#{ids}) and item_type <> 'i'").sum('amount')
			itemCount = @populateItems.sum('quantity')
			overHeadPrice = otherCharges.to_f/itemCount.to_f
			@populateItems.each do|item|
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
				inventory.supplier_invoice_id = item.invoice_id
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
			@shipmentItem = @shipment.inventory_items.shipment_item 
		end		
	end
  
	def update
		errorMsg = nil
		shipmentItem = nil
		arrId = nil
		unless params["shipment_id"].blank?
			@shipment = WkShipment.find(params["shipment_id"].to_i)
			arrId = @shipment.inventory_items.shipment_item.pluck(:id)
		else
			@shipment = WkShipment.new
			@shipment.shipment_type = 'I'
			@shipment.parent_id = params[:parent_id]
			@shipment.parent_type = params[:parent_type]
		end
		@shipment.shipment_date = params[:shipment_date]		
		@shipment.serial_number = params[:serial_number]
		@shipment.save()
		totalAmount = 0
		tothash = Hash.new
		totalRow = params[:totalrow].to_i
		savedRows = 0
		deletedRows = 0
		sysCurrency = Setting.plugin_redmine_wktime['wktime_currency']
		assetAccountingHash = Hash.new
		assetTotal = 0
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
			unless isUsedInventoryItem(shipmentItem)
				shipmentItem.product_item_id = params["product_item_id#{i}"].to_i
				shipmentItem.product_attribute_id = params["product_attribute_id#{i}"]
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
				shipmentItem.product_type = params["product_type#{i}"]
				shipmentItem.notes = params["notes#{i}"]
				shipmentItem.available_quantity = params["total_quantity#{i}"] if shipmentItem.new_record? || shipmentItem.available_quantity == shipmentItem.total_quantity
				shipmentItem.total_quantity = params["total_quantity#{i}"]
				shipmentItem.status = 'o'
				shipmentItem.uom_id = params["uom_id#{i}"].to_i unless params["uom_id#{i}"].blank?
				shipmentItem.location_id = params["location_id#{i}"].to_i if !params["location_id#{i}"].blank? && params["location_id#{i}"] != "0"
				shipmentItem.project_id = params["project_id#{i}"].to_i if !params["project_id#{i}"].blank? && params["project_id#{i}"] != "0"
				if params["product_type#{i}"] == 'A' || params["product_type#{i}"] == 'RA'
					assetValue = (shipmentItem.total_quantity*(shipmentItem.cost_price+shipmentItem.over_head_price))
					assetTotal = assetTotal + assetValue
					accountingLedger = WkProductItem.find(shipmentItem.product_item_id).product.ledger_id
					ledgerId = ((!accountingLedger.blank? && accountingLedger > 0) ? accountingLedger : getSettingCfId("inventory_db_ledger"))
					assetAccountingHash[ledgerId] = assetAccountingHash[ledgerId].blank? ? assetValue : assetAccountingHash[ledgerId] + assetValue
					quantity = params["total_quantity#{i}"].to_i
					shipmentItem.available_quantity = 1
					shipmentItem.total_quantity = 1
					for i in 1 .. quantity - 1
						dupItem = shipmentItem.dup
						# Below code for set parent id as shipment item id
						# dupItem.available_quantity = 1
						# dupItem.total_quantity = 1
						# dupItem.parent_id = shipmentItem.id
						dupItem.save
						postAssetProperties(dupItem)
					end
				end
				shipmentItem.save()
				postAssetProperties(shipmentItem)
			end
			savedRows = savedRows + 1
		end
		
		if !arrId.blank?
			WkInventoryItem.where(:id => arrId).delete_all
		end
		
		postShipmentAccounting(@shipment, assetAccountingHash, assetTotal)
		
		if errorMsg.nil? 
			redirect_to :action => 'index' , :tab => controller_name
			flash[:notice] = l(:notice_successful_update)
	   else
			flash[:error] = errorMsg
			redirect_to :action => 'edit', :shipment_id => @shipment.id
	   end
	end
	
	
	
	def destroy
		begin
			shipment = WkShipment.find(params[:shipment_id].to_i)
			if shipment.destroy
				flash[:notice] = l(:notice_successful_delete)
			else
				flash[:error] = shipment.errors.full_messages.join("<br>")
			end
		rescue => ex
			flash[:error] = l(:error_shipment_items_used)
		end
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end

	def set_filter_session
		session[controller_name] = {:from => @from, :to => @to} if session[controller_name].nil?
		if params[:searchlist] == controller_name
			filters = [:period_type, :period, :contact_id, :account_id, :project_id, :polymorphic_filter, :rfq_id, :from, :to]
			filters.each do |param|
				if params[param].blank? && session[controller_name].try(:[], param).present?
					session[controller_name].delete(param)
				elsif params[param].present?
					session[controller_name][param] = params[param]
				end
			end
		end
	end
	
	def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		@shipmentEntries = entries.order(shipment_date: :desc).limit(@limit).offset(@offset)
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
		if params[:update_DD] == 'product_attribute_id' && !params[:product_id].blank?
			product = WkProduct.find(params[:product_id].to_i)
			unless product.blank?
				productAttr = product.product_attributes
				itemArr << "" + ',' +  "" + "\n"
				productAttr.each do |item|
					itemArr << item.id.to_s() + ',' +  item.name + "\n"
				end
			end
		elsif params[:update_DD] == 'product_type' && !params[:product_id].blank?
			product = WkProduct.find(params[:product_id].to_i)
			productTypeHash = getProductTypeHash(false)
			unless product.blank?
				unless product.product_type.blank?
					itemArr << product.product_type.to_s() + ',' +  productTypeHash[product.product_type] + "\n"
				else
					productTypeHash.each do |key, val|
						itemArr << key + ',' +  val + "\n"
					end
				end
			end
		else
			productItemArr = getProductItemArr(sqlCond, false)
			productItemArr.each do |item|
				itemArr << item[1].to_s() + ',' +  item[0] + "\n"
			end
		end
		respond_to do |format|
			format.text  { render :plain => itemArr }
		end
	end
	
	def getSupplierInvoices
		siArr = ""
		siObj = WkInvoice.where(:parent_type=> params[:parent_type], :parent_id=>params[:parent_id], :invoice_type => 'SI')
		unless siObj.blank?
			siObj.each do |item|
				siArr << item.id.to_s() + ',' +  item.invoice_number.to_s() + "\n"
			end
		end
		respond_to do |format|
			format.text  { render :plain => siArr }
		end
	end
	
	def postAssetProperties(inventoryItem)
		assetObj = WkAssetProperty.where(:inventory_item_id => inventoryItem.id).first_or_initialize(:inventory_item_id => inventoryItem.id, :name => (inventoryItem.product_item.product.name.to_s + inventoryItem.id.to_s), :current_value => (inventoryItem.cost_price.to_f + inventoryItem.over_head_price.to_f).round(2), :owner_type => 'O', :rate_per => 'h') 
		assetObj.save
	end
	
	def additionalContactType
		false
	end
	
end
