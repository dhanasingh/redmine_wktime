class WklogmaterialController < ApplicationController
  unloadable
  before_filter :require_login




  def index
  end 
  
  def modifyProductDD
		pctArr = ""	
		if params[:ptype] == "product"
			pctObj = WkProduct.where(:category_id => params[:id]).order(:name)
		elsif params[:ptype] == "brand_id"
			pObj = WkProduct.find(params[:id].to_i)
			pctObj = pObj.brands.order(:name)
		elsif params[:ptype] == "product_item"
			sqlQuery = "select it.id, pi.product_id, pi.brand_id, wb.name as brand_name, it.product_attribute_id, pi.product_model_id, wpm.name as product_model_name, pi.part_number, it.cost_price, it.selling_price, it.currency, it.available_quantity, it.uom_id from wk_inventory_items it left outer join wk_product_items pi on pi.id = it.product_item_id left outer join wk_brands wb on wb.id = pi.brand_id left outer join wk_product_models wpm on wpm.id = pi.product_model_id where pi.product_id = #{params[:id]} and it.available_quantity > 0"
			
			# sqlQuery = "select it.id, pi.product_id, pi.brand_id, pi.product_attribute_id, pi.product_model_id, pi.part_number, it.cost_price, it.selling_price, it.currency, it.available_quantity, it.uom_id from wk_product_items pi left outer join wk_inventory_items it on pi.id = it.id where pi.product_id = #{params[:id]}"
			pctObj = WkInventoryItem.find_by_sql(sqlQuery)
			#pctObj = WkProductItem.where(:product_id => params[:product_id], :brand_id => params[:id])
		elsif params[:ptype] == "product_model_id"
			unless params[:id].blank? || params[:id].to_i < 1
				pObj = WkBrand.find(params[:id].to_i)
				pctObj = pObj.product_models.where(:product_id => params[:product_id].to_i).order(:name)
			else
				pctObj = []
			end
		elsif params[:ptype] == "product_attribute_id"
			pObj = WkProduct.find(params[:id].to_i)
			pctObj = pObj.product_attributes.order(:name)
		elsif params[:ptype] == "uom_id"
			pctObj = WkInventoryItem.find(params[:id].to_i)			
		else
			#pctObj = WkProductItem.find(params[:id].to_i) unless params[:id].blank?
			pctObj = WkInventoryItem.find(params[:id].to_i) unless params[:id].blank?
		end
		
		if params[:ptype] == "product_item"
			pctObj.each do | entry|
				attributeName = entry.product_attribute.blank? ? "" : entry.product_attribute.name
				pctArr << entry.id.to_s() + ',' +  (entry.brand_name.to_s() +' - '+ entry.product_model_name.to_s() +' - '+ entry.part_number.to_s() +' - '+ attributeName  +' - '+  (entry.currency.to_s() + ' ' +  entry.selling_price.to_s()) ) + "\n" 
			end
		elsif params[:ptype] == "inventory_item"
			pctArr << pctObj.id.to_s() + ',' + pctObj.available_quantity.to_s() +','+ pctObj.cost_price.to_s()  +','+  pctObj.currency.to_s() + ',' +  pctObj.selling_price.to_s() unless pctObj.blank?
		elsif params[:ptype] == "product_attribute"
			pctArr << pctObj.id.to_s() + ',' + pctObj.available_quantity.to_s() +','+ pctObj.cost_price.to_s()  +','+  pctObj.currency.to_s() + ',' +  pctObj.selling_price.to_s() unless pctObj.blank?  
		elsif params[:ptype] == "uom_id"
			#pctObj.each do | entry|
				pctArr << pctObj.uom_id.to_s() + ',' +  pctObj.uom.name.to_s()  + "\n"
			#end
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
