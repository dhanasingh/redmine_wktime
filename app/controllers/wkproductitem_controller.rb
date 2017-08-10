class WkproductitemController < ApplicationController
  unloadable



  def index
  end
	
	def edit
	    @productItem = nil
	    unless params[:product_item_id].blank?
		   @productItem = WkProductItem.find(params[:product_item_id])
		end 
	end	
    
	def update	
		if params[:product_item_id].blank?
		  productItem = WkProductItem.new
		  existingItem = WkProductItem.where(:part_number => params[:part_number], :product_id => params[:product_id], :brand_id => params[:brand_id], :product_model_id => params[:product_model_id], :product_attribute_id => params[:product_attribute_id])
		  productItem = existingItem[0] unless existingItem[0].blank?
		else
		  productItem = WkProductItem.find(params[:product_item_id])
		end
		productItem.part_number = params[:part_number]
		productItem.product_id = params[:product_id]
		productItem.brand_id = params[:brand_id]
		productItem.product_model_id = params[:product_model_id]
		productItem.product_attribute_id = params[:product_attribute_id]
		if productItem.save()
		    redirect_to :controller => 'wkproductitem',:action => 'index' , :tab => 'wkproductitem'
		    flash[:notice] = l(:notice_successful_update)
		else
		    redirect_to :controller => 'wkproductitem',:action => 'index' , :tab => 'wkproductitem'
		    flash[:error] = rfq.errors.full_messages.join("<br>")
		end
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
