class WkcrmaccountController < WkaccountController
	unloadable
	menu_item :wklead
	accept_api_auth :index, :edit, :update

	def getAccountType
		'A'
	end		
end
