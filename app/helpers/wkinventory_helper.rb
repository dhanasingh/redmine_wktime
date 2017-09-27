module WkinventoryHelper
	include WktimeHelper

	def getProductTypeHash(needBlank)		
		productType = { 'I'  => l(:label_inventory), 'A' =>  l(:label_asset) }
		if needBlank
			productType = { '' => "", 'I'  => l(:label_inventory), 'A' =>  l(:label_asset) }
		end
		productType
	end
	
	def getDepreciationTypeHash(needBlank)		
		productType = { 'SL'  => l(:label_stright_line), 'A' =>  l(:label_wov) }
		if needBlank
			productType = { '' => "", 'SL'  => l(:label_stright_line), 'WOV' =>  l(:label_wov) }
		end
		productType
	end
	
	def getFrequencyMonth(periodType)
		case periodType
		when 'A'
		  val = 11
		when 'SA'
		  val = 5
		when 'Q'
		  val = 2
		when 'M'
		  val = 0
		else
		  raise ArgumentError, 'invalid arguments to period'
		end
	end
end
