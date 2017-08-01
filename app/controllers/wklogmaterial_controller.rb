class WklogmaterialController < ApplicationController
  unloadable



  def index
  end 
  
  def modifyProductDD
		pctArr = ""	
		if params[:ptype] == "product"
			pctObj = WkProduct.where(:category_id => params[:id]).order(:name)
		elsif params[:ptype] == "product_brand"
			pObj = WkProduct.find(params[:id].to_i)
			pctObj = pObj.brands.order(:name)
		elsif params[:ptype] == "product_item"
			pctObj = WkProductItem.where(:product_id => params[:product_id], :brand_id => params[:id])
		else
			pctObj = WkProductItem.find(params[:id].to_i) unless params[:id].blank?
		end
		
		if params[:ptype] == "product_item"
			pctObj.each do | entry|
				pctArr << entry.id.to_s() + ',' +  (entry.part_number.to_s() +' - '+ entry.product_attribute.name.to_s()  +' - '+  (entry.currency.to_s() + ' ' +  entry.selling_price.to_s()) ) + "\n" 
			end
		elsif params[:ptype] == "product_attribute"
			pctArr << pctObj.id.to_s() + ',' + pctObj.available_quantity.to_s() +','+ pctObj.cost_price.to_s()  +','+  pctObj.currency.to_s() + ',' +  pctObj.selling_price.to_s() unless pctObj.blank?  			
		else		
			pctObj.each do | entry|
				pctArr << entry.id.to_s() + ',' +  entry.name.to_s()  + "\n" 
			end
		end
		
		respond_to do |format|
			format.text  { render :text => pctArr }
		end
	end  
end
