class WkproductitemController < ApplicationController
  unloadable
  
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
    
	def update
		existingItem = WkProductItem.where(:product_id => params[:product_id], :brand_id => params[:brand_id], :product_model_id => params[:product_model_id], :product_attribute_id => params[:product_attribute_id])	
		if params[:product_item_id].blank?
			productItem = WkProductItem.new
			productItem = existingItem[0] unless existingItem[0].blank?
		else
			productItem = existingItem[0]
			productItem = WkProductItem.new if existingItem[0].blank?
			#productItem = WkProductItem.find(params[:product_item_id])
		end
		productItem.part_number = params[:part_number]
		productItem.product_id = params[:product_id]
		productItem.brand_id = params[:brand_id]
		productItem.product_model_id = params[:product_model_id]
		productItem.product_attribute_id = params[:product_attribute_id]
		if productItem.save()
			updateInventoryItem(productItem.id)
		    redirect_to :controller => 'wkproductitem',:action => 'index' , :tab => 'wkproductitem'
		    flash[:notice] = l(:notice_successful_update)
		else
		    redirect_to :controller => 'wkproductitem',:action => 'index' , :tab => 'wkproductitem'
		    flash[:error] = rfq.errors.full_messages.join("<br>")
		end
    end
	
	def updateInventoryItem(productItemId)
		if params[:inventory_item_id].blank?
			inventoryItem = WkInventoryItem.new
		else
			inventoryItem = WkInventoryItem.find(params[:inventory_item_id].to_i)
		end
		inventoryItem.product_item_id = productItemId
		inventoryItem.serial_number = params[:serial_number]
		inventoryItem.notes = params[:notes]
		inventoryItem.currency = params[:currency]
		inventoryItem.cost_price = params[:cost_price]
		inventoryItem.over_head_price = params[:over_head_price]
		inventoryItem.selling_price = params[:selling_price]
		inventoryItem.org_currency = params[:org_currency]
		inventoryItem.org_cost_price = params[:org_cost_price]
		inventoryItem.org_over_head_price = params[:org_over_head_price]
		inventoryItem.org_selling_price = params[:org_selling_price]
		inventoryItem.total_quantity = params[:total_quantity]
		inventoryItem.available_quantity = params[:available_quantity]
		inventoryItem.status = inventoryItem.available_quantity == 0 ? 'c' : 'o'
		inventoryItem.uom_id = params[:uom_id].to_i
		inventoryItem.location_id = params[:location_id].to_i
		inventoryItem.save()
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
