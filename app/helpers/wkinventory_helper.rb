module WkinventoryHelper
	include WktimeHelper

	def getProductTypeHash(needBlank)		
		productType = { 'I'  => l(:label_inventory), 'A' =>  l(:label_asset) }
		if needBlank
			productType = { '' => "", 'I'  => l(:label_inventory), 'A' =>  l(:label_asset) }
		end
		additionalProducts = call_hook :additional_product_type
		unless additionalProducts.blank?
			if additionalProducts.is_a?(Array) 
				additionalProducts.each do | hsh |
					productType =  productType.merge(hsh)
				end
			else
				mergeHash = eval(additionalProducts)
				productType =  productType.merge(mergeHash)
			end
		end
		productType
	end
	
	def getDepreciationTypeHash(needBlank)		
		productType = { 'SL'  => l(:label_stright_line), 'WDV' =>  l(:label_wdv) }
		if needBlank
			productType = { '' => "", 'SL'  => l(:label_stright_line), 'WDV' =>  l(:label_wdv) }
		end
		productType
	end
	
	def getFrequencyMonth(periodType)
		val = nil
		case periodType
		when 'a'
		  val = 12
		when 'sa'
		  val = 6
		when 'q'
		  val = 3
		when 'm'
		  val = 1
		else
		  raise ArgumentError, 'invalid arguments to period'
		end
		val
	end
end
