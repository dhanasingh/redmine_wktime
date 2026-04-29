class WkinventoryController < WkbaseController


before_action :require_login

include WktimeHelper
before_action :check_basic_perm, :only => [:index, :edit, :update, :destroy]
before_action :check_admin_perm, :only => [:destroy]


	def check_basic_perm
		unless check_permission
			render_403
			return false
		end
	end

	def check_permission
		return validateERPPermission("B_INV_PRVLG")
	end

	def check_admin_perm
		allow = false
		allow = validateERPPermission("A_INV_PRVLG")
		unless allow
			render_403
			return false
		end
	end

	def hasDeletePermission
		validateERPPermission("A_INV_PRVLG")
	end
end
