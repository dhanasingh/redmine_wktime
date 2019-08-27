class WkcrmaccountController < WkaccountController
  unloadable
  menu_item :wklead
  
	def getAccountType
		'A'
	end		
end
