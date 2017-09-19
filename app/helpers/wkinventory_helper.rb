module WkinventoryHelper
	include WktimeHelper

	def getProductTypeHash(needBlank)		
		productType = { 'I'  => l(:label_inventory), 'A' =>  l(:label_asset) }
		if needBlank
			productType = { '' => "", 'I'  => l(:label_inventory), 'A' =>  l(:label_asset) }
		end
		productType
	end
end
