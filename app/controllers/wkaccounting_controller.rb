class WkaccountingController < WkbaseController	
  unloadable
  include WkaccountingHelper
	def index
	end
	
	def pl_rpt	
		@from = session[:wkreport][:from]
		@to = session[:wkreport][:to]
		@profitLossEntries = getTransDetails(@from,@to)
		render :action => 'pl_rpt', :layout => false
	end
end
