class WksupplieraccountController < WkaccountController
  unloadable

	include WktimeHelper


  
	def getAccountType
		'S'
	end

end
