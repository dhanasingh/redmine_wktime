class WkbillingController < WkbaseController

before_filter :require_login

include WktimeHelper
before_filter :check_perm_and_redirect, :only => [:index,:edit, :update, :destroy] # user without

	def index  
	end
	
	def check_perm_and_redirect
		unless check_permission
			render_403
			return false
		end
	end
	
	def check_permission
		return (isBillingAdmin)
	end
	
	def index
	end
	
	def edit
	end
	
	def update
	end
	
	def destroy
	end
	
end