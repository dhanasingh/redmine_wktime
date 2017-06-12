class WksupplierorderentityController < WkorderentityController
  unloadable


	
	def getOrderAccountType
		'S'
	end
	
	def getOrderContactType
		'SC'
	end
	
	def needBlankForProject
		true
	end
	
	def requireRfqDD
		true
	end
	
	def isPopulateCheckBox
		true
	end
end
