module WklogmaterialHelper
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
	
	def getProductBrandArray(productId, needBlank)
		pctArr = WkProduct.find(productId)
		pctBrandArr = pctArr.brands.order(:name).pluck(:name, :id)
		pctBrandArr.unshift(["",'']) if needBlank
		pctBrandArr
	end
	
	def getProductItemArr(productId, brandId, needBlank)
		pItemObj = WkProductItem.where(:product_id => productId, :brand_id => brandId)
		pctItemArr = pItemObj.collect{|i| [ "#{i.part_number} - #{i.product_attribute.name} - #{i.currency}#{i.selling_price} ", i.id ] }
		pctItemArr.unshift(["",'']) if needBlank
		pctItemArr
	end	
end
