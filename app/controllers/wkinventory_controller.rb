class WkinventoryController < WkbaseController
  unloadable

before_action :require_login

include WktimeHelper
before_action :check_perm_and_redirect, :only => [:index, :edit, :update, :destroy]
before_action :check_admin_redirect, :only => [:destroy]

	
	def check_perm_and_redirect
		unless check_permission
			render_403
			return false
		end
	end
	
	def check_permission
		return validateERPPermission("V_INV")
	end
	
	def check_admin_redirect
		allow = false
		allow = validateERPPermission("D_INV")
		unless allow
			render_403
			return false
		end
	end
	
	def hasDeletePermission
		validateERPPermission("D_INV")
	end


end
