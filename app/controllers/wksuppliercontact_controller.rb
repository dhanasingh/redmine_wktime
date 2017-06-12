class WksuppliercontactController < WkcontactController
	unloadable

	include WktimeHelper
  
	def getContactType
		'SC'
	end
	
	def getContactController
		'wksuppliercontact'
	end
	
	def getAccountType
		'S'
	end

end
