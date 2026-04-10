class WkcrmaccountController < WkaccountController
 
	menu_item :wklead
	accept_api_auth :index, :edit, :update
  before_action :init_survey

	def getAccountType
		'A'
	end

	def init_survey
		@survey_ctrl = "wksurvey"
		@survey_perm = validateERPPermission("E_SUR")
	end
end
