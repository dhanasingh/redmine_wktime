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
	
	def balance_sheet
		@to = session[:wkreport][:to]
		@from = @to.month >3 ? @to.change(day: 1, month: 4) : @to.change(day: 1, month: 4, year: @to.year-1)
		@profitLossEntries = getTransDetails(@from,@to)
		render :action => 'balance_sheet', :layout => false
	end
end
