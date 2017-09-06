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
		sqlQuery = "select it.id, pi.product_id, pi.brand_id, wb.name as brand_name, it.product_attribute_id, pi.product_model_id, wpm.name as product_model_name, pi.part_number, it.cost_price, it.selling_price, it.currency, it.available_quantity, it.uom_id from wk_inventory_items it left outer join wk_product_items pi on pi.id = it.product_item_id left outer join wk_brands wb on wb.id = pi.brand_id left outer join wk_product_models wpm on wpm.id = pi.product_model_id where pi.product_id = #{productId} and it.available_quantity > 0"
		pctObj = WkInventoryItem.find_by_sql(sqlQuery)
		pctObj
	end

	def getPdtItemArr(productId, needBlank)
		pctObj = mergePItemInvItemQuery(productId)
		pctArr = Array.new
		pctObj.each do | entry|
			attributeName = entry.product_attribute.blank? ? "" : entry.product_attribute.name
			pctArr <<  [(entry.brand_name.to_s() +' - '+ entry.product_model_name.to_s() +' - '+ attributeName + ' - '+ entry.part_number.to_s() +' - '+  (entry.currency.to_s() + ' ' +  entry.selling_price.to_s()) ),  entry.id.to_s()]
		end
		pctArr.unshift(["",'']) if needBlank
		pctArr
	end
	
	def getUOMArray(uomId, needBlank)
		uomArr = Array.new
		if uomId.blank?
			uomArr = WkMesureUnit.all.pluck(:name, :id)
		else
			uomArr = WkMesureUnit.find(uomId).pluck(:name, :id)
		end
		uomArr.unshift(["",'']) if needBlank
		uomArr
	end
	
	def updateParentInventoryItem(inventoryItemId, productQuantity, materialQuantity)
		inventoryItemObj = WkInventoryItem.find(inventoryItemId)
		if materialQuantity.blank?
			totalAvlQty = inventoryItemObj.available_quantity
			materialQuantity = 0
		else 
			totalAvlQty = inventoryItemObj.available_quantity + materialQuantity
		end
		
		if  totalAvlQty >= productQuantity 
			qtyVal = materialQuantity - productQuantity
			inventoryItemObj.incrementAvaQty(qtyVal)
			inventoryItemObj.save
		end
		inventoryItemObj
	end
	
end
