class WkinventoryController < WkbaseController
  unloadable

before_filter :require_login

include WktimeHelper
before_filter :check_perm_and_redirect, :only => [:index, :edit, :update, :destroy]
before_filter :check_admin_redirect, :only => [:destroy]

	
	def check_perm_and_redirect
		unless check_permission
			render_403
			return false
		end
	end
	
	def check_permission
		return isModuleAdmin('wktime_inventory_group') || isModuleAdmin('wktime_inventory_admin')
	end
	
	def check_admin_redirect
		allow = false
		allow = isModuleAdmin('wktime_inventory_admin')
		unless allow
			render_403
			return false
		end
	end


end
