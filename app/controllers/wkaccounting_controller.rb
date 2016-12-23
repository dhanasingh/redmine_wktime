class WkaccountingController < WkbaseController	
  unloadable
	before_filter :require_login
	before_filter :check_perm_and_redirect, :only => [:index, :edit, :update, :pl_rpt]
	before_filter :check_ac_admin_and_redirect, :only => [:destroy]
	include WkaccountingHelper
	def index
	end
	
	def pl_rpt	
		@from = session[:wkreport][:from]
		@to = session[:wkreport][:to]
		@profitLossEntries = getTransDetails(@from,@to)
		render :action => 'pl_rpt', :layout => false
	end
	
	def balance_sheet
		@to = session[:wkreport][:to]
		@from = @to.month >3 ? @to.change(day: 1, month: 4) : @to.change(day: 1, month: 4, year: @to.year-1)
		@profitLossEntries = getTransDetails(@from,@to)
		render :action => 'balance_sheet', :layout => false
	end
	
	def check_perm_and_redirect
		unless check_permission
			render_403
			return false
		end
	end
	
	def check_ac_admin_and_redirect
	  unless isModuleAdmin('wktime_accounting_admin') 
	    render_403
	    return false
	  end
    end

	def check_permission
		ret = false
		#ret = params[:user_id].to_i == User.current.id
		return isModuleAdmin('wktime_accounting_group') || isModuleAdmin('wktime_accounting_admin') 
	end
end
