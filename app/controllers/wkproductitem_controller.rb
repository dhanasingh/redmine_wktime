class WkproductitemController < WkinventoryController
  unloadable 
  before_filter :require_login
  before_filter :check_perm_and_redirect, :only => [:index, :edit, :update, :destroy, :transfer, :updateTransfer]

  include WktimeHelper
  include WkgltransactionHelper
  
	#before_filter :check_deletable_redirect, :only => [:destroy]
  
	def index
		set_filter_session
		productId = session[controller_name][:product_id]
		brandId = session[controller_name][:brand_id]
		sqlwhere = ""
		unless productId.blank?
			sqlwhere = " pit.product_id = #{productId}"
		end
		
		unless brandId.blank?
			sqlwhere = sqlwhere + " AND" unless sqlwhere.blank?
			sqlwhere = sqlwhere + " pit.brand_id = #{brandId}"
		end
		sqlwhere = " where" + sqlwhere unless sqlwhere.blank?
		sqlStr = getProductInventorySql + sqlwhere
		findBySql(sqlStr, WkProductItem)
	end
	
	def getProductInventorySql
		sqlStr = "select iit.id as inventory_item_id, pit.id as product_item_id, iit.status, p.name as product_name, b.name as brand_name, m.name as product_model_name, a.name as product_attribute_name, iit.serial_number, iit.currency, iit.selling_price, iit.total_quantity, iit.available_quantity, uom.short_desc as uom_short_desc, l.name as location_name from wk_product_items pit 
		left outer join wk_inventory_items iit on iit.product_item_id = pit.id 
		left outer join wk_products p on pit.product_id = p.id
		left outer join wk_brands b on pit.brand_id = b.id
		left outer join wk_product_models m on pit.product_model_id = m.id
		left outer join wk_product_attributes a on iit.product_attribute_id = a.id
		left outer join wk_locations l on iit.location_id = l.id
		left outer join wk_mesure_units uom on iit.uom_id = uom.id"
		sqlStr
	end
	
	def edit
	    @productItem = nil
		@inventoryItem = nil
	    unless params[:product_item_id].blank?
		   @productItem = WkProductItem.find(params[:product_item_id])
		end 
		unless params[:inventory_item_id].blank?
		   @inventoryItem = WkInventoryItem.find(params[:inventory_item_id])
		end 
	end	
	
	def transfer
		unless params[:inventory_item_id].blank?
		   @transferItem = WkInventoryItem.find(params[:inventory_item_id])
		end 
	end	
	
	def update
		existingItem = WkProductItem.where(:product_id => params[:product_id], :brand_id => params[:brand_id], :product_model_id => params[:product_model_id])	#, :product_attribute_id => params[:product_attribute_id]
		if params[:product_item_id].blank?
			productItem = WkProductItem.new
			productItem = existingItem[0] unless existingItem[0].blank?
		else
			productItem = existingItem[0]
			productItem = WkProductItem.new if existingItem[0].blank?
		end
		productItem.part_number = params[:part_number]
		productItem.product_id = params[:product_id]
		productItem.brand_id = params[:brand_id]
		productItem.product_model_id = params[:product_model_id]
		#productItem.product_attribute_id = params[:product_attribute_id]
		if productItem.save()
			if !params[:available_quantity].blank?
				updatedInventory = updateInventoryItem(productItem.id) 
			elsif !params[:inventory_item_id].blank?
				inventoryItem = WkInventoryItem.find(params[:inventory_item_id].to_i)
				inventoryItem.selling_price = params[:selling_price]
				inventoryItem.save
			end
		    redirect_to :controller => 'wkproductitem',:action => 'index' , :tab => 'wkproductitem'
		    flash[:notice] = l(:notice_successful_update)
		else
		    redirect_to :controller => 'wkproductitem',:action => 'edit' , :product_item_id => params[:product_item_id], :inventory_item_id => params[:inventory_item_id], :tab => 'wkproductitem'
		    flash[:error] = productItem.errors.full_messages.join("<br>")
		end
    end
    
	def updateTransfer
		sourceItem = WkInventoryItem.find(params[:transfer_item_id].to_i)
		sourceItem.available_quantity = sourceItem.available_quantity - (params[:total_quantity].blank? ? params[:available_quantity].to_i : params[:total_quantity].to_i)
		if sourceItem.save()
			targetItem = updateInventoryItem(params[:product_item_id].to_i)
		    redirect_to :controller => 'wkproductitem',:action => 'index', :tab => 'wkproductitem'
		    flash[:notice] = l(:notice_successful_update)
		else
		    redirect_to :controller => 'wkproductitem',:action => 'index', :tab => 'wkproductitem'
		    flash[:error] = sourceItem.errors.full_messages.join("<br>")
		end
	end
	
	def updateInventoryItem(productItemId)
		sysCurrency = Setting.plugin_redmine_wktime['wktime_currency']
		if params[:inventory_item_id].blank?
			inventoryItem = WkInventoryItem.new
		else
			inventoryItem = WkInventoryItem.find(params[:inventory_item_id].to_i)
		end
		
		unless params[:transfer_item_id].blank?
			transferItem = WkInventoryItem.find(params[:transfer_item_id].to_i)
			inventoryItem = transferItem.dup
			inventoryItem.parent_id = params[:transfer_item_id].to_i
			inventoryItem.supplier_invoice_id = nil
			inventoryItem.lock_version = 0
			inventoryItem.shipment_id = nil
		else
			inventoryItem.product_item_id = productItemId
			inventoryItem.serial_number = params[:serial_number]
			inventoryItem.product_attribute_id = params[:product_attribute_id]
			if sysCurrency != params[:currency]
				inventoryItem.org_currency = params[:currency]
				inventoryItem.org_cost_price = params[:cost_price]
				inventoryItem.org_over_head_price = params[:over_head_price]
				inventoryItem.org_selling_price = params[:selling_price]
			end
			inventoryItem.currency = sysCurrency
			inventoryItem.cost_price = getExchangedAmount(params[:currency], params[:cost_price]) 
			inventoryItem.over_head_price = getExchangedAmount(params[:currency], params[:over_head_price]) 
		end
		inventoryItem.notes = params[:notes]
		inventoryItem.selling_price = getExchangedAmount(params[:currency], params[:selling_price])
		inventoryItem.total_quantity = params[:total_quantity]
		inventoryItem.total_quantity = params[:available_quantity] if params[:total_quantity].blank?
		inventoryItem.available_quantity = params[:available_quantity]
		inventoryItem.status = inventoryItem.available_quantity == 0 ? 'c' : 'o'
		inventoryItem.uom_id = params[:uom_id].to_i
		inventoryItem.location_id = params[:location_id].to_i
		inventoryItem.save()
		inventoryItem
	end
	
	def destroy
		inventoryItem = nil
		productItem = WkProductItem.find(params[:product_item_id].to_i)
		unless params[:inventory_item_id].blank?
			inventoryItem = WkInventoryItem.find(params[:inventory_item_id].to_i)
			shipment = inventoryItem.shipment
			if inventoryItem.destroy
				invCount = productItem.inventory_items.count
				shipInvCount = 0
				shipInvCount = shipment.inventory_items.count unless shipment.blank?
				productItem.destroy unless invCount>0
				shipment.destroy unless shipInvCount>0 || shipment.blank?
				flash[:notice] = l(:notice_successful_delete)
			else
				flash[:error] = inventoryItem.errors.full_messages.join("<br>")
			end
		else
			# productItem = WkProductItem.find(params[:product_item_id].to_i)
			if productItem.destroy
				flash[:notice] = l(:notice_successful_delete)
			else
				flash[:error] = inventoryItem.errors.full_messages.join("<br>")
			end
		end
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end	  

	def set_filter_session
		if params[:searchlist].blank? && session[controller_name].nil?
			session[controller_name] = {:product_id => params[:product_id], :brand_id => params[:brand_id]}
		elsif params[:searchlist] == controller_name
			session[controller_name][:product_id] = params[:product_id]
			session[controller_name][:brand_id] = params[:brand_id]
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
	
	def findBySql(query, model)
		result = model.find_by_sql("select count(*) as id from (" + query + ") as v2")
		@entry_count = result.blank? ? 0 : result[0].id
        setLimitAndOffset()		
		rangeStr = formPaginationCondition()
		@productInventory = model.find_by_sql(query + " order by iit.id desc " + rangeStr )
	end
	
	def formPaginationCondition
		rangeStr = ""
		if ActiveRecord::Base.connection.adapter_name == 'SQLServer'				
			rangeStr = " OFFSET " + @offset.to_s + " ROWS FETCH NEXT " + @limit.to_s + " ROWS ONLY "
		else		
			rangeStr = " LIMIT " + @limit.to_s +	" OFFSET " + @offset.to_s
		end
		rangeStr
	end	


end
