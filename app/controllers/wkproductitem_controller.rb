class WkproductitemController < ApplicationController
  unloadable 
  include WktimeHelper
  include WkgltransactionHelper
  
	def index
		@productInventory = WkInventoryItem.all
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
		existingItem = WkProductItem.where(:product_id => params[:product_id], :brand_id => params[:brand_id], :product_model_id => params[:product_model_id], :product_attribute_id => params[:product_attribute_id])	
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
		productItem.product_attribute_id = params[:product_attribute_id]
		if productItem.save()
			updatedInventory = updateInventoryItem(productItem.id) unless params[:available_quantity].blank?
		    redirect_to :controller => 'wkproductitem',:action => 'index' , :tab => 'wkproductitem'
		    flash[:notice] = l(:notice_successful_update)
		else
		    redirect_to :controller => 'wkproductitem',:action => 'index' , :tab => 'wkproductitem'
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
		#WkRfq.find(params[:rfq_id].to_i).destroy
		#flash[:notice] = l(:notice_successful_delete)
		productItem = WkRfq.find(params[:product_item_id].to_i)
		if productItem.destroy
			flash[:notice] = l(:notice_successful_delete)
		else
			flash[:error] = productItem.errors.full_messages.join("<br>")
		end
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end	

end
