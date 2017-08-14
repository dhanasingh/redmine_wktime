module WklogmaterialHelper
include ApplicationHelper
include WktimeHelper
	def getLogHash
		{
			'T' => l(:label_wktime),
			'M' => l(:label_material)
		}
	end
	
	def getProductCatagoryArray(model, categoryId, needBlank)
		if categoryId.blank?
			pctCatArr = model.all.order(:name).pluck(:name, :id)
		else
			pctCatArr = model.all.order(:name).pluck(:name, :id) #where(:category_id => categoryId).order(:name).pluck(:name, :id)
		end		
		pctCatArr.unshift(["",'']) if needBlank
		pctCatArr
	end
	
	def getProductArray(model, productId, needBlank)
		if productId.blank?
			pdtArr = model.all.order(:name).pluck(:name, :id)
		else
			pdtArr = model.where(:id => productId.to_i).pluck(:name, :id)
		end
		pdtArr.unshift(["",'']) if needBlank
		pdtArr
	end
	
	def getProductBrandArray(productId, needBlank)
		pctArr = WkProduct.find(productId)
		pctBrandArr = pctArr.brands.order(:name).pluck(:name, :id)
		pctBrandArr.unshift(["",'']) if needBlank
		pctBrandArr
	end
	
	def getProductItemArr(productId, needBlank)
		pItemObj = WkProductItem.where(:product_id => productId)
		pctItemArr = pItemObj.collect{|i| [ "#{i.part_number} - #{i.product_attribute.name} - #{i.currency}#{i.selling_price} ", i.id ] }
		pctItemArr.unshift(["",'']) if needBlank
		pctItemArr
	end
	
	def mergePItemInvItemQuery(productId)
		sqlQuery = "select it.id, pi.product_id, pi.brand_id, pi.product_attribute_id, pi.product_model_id, pi.part_number, it.cost_price, it.selling_price, it.currency, it.available_quantity, it.uom_id from wk_product_items pi left outer join wk_inventory_items it on pi.id = it.id where pi.product_id = #{productId}"
		pctObj = WkProductItem.find_by_sql(sqlQuery)
		pctObj
	end

	def getPdtItemArr(productId, needBlank)
		pctObj = mergePItemInvItemQuery(productId)
		pctArr = Array.new
		pctObj.each do | entry|
			pctArr << entry.id.to_s() + ',' +  (entry.part_number.to_s() +' - '+ entry.product_attribute.name.to_s()  +' - '+  (entry.currency.to_s() + ' ' +  entry.selling_price.to_s()) )  
		end
		pctArr.unshift(["",'']) if needBlank
		pctArr
	end
end
