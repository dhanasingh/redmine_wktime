class WksupplieraccountController < WkaccountController
  unloadable

	include WktimeHelper


  
	def getAccountType
		'S'
	end
	
	def getContactController
		'wksuppliercontact'
	end

end
