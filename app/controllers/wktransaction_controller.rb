class WktransactionController < WkaccountingController
  unloadable



   def index
	 set_filter_session
     retrieve_date_range
   end
   
   def edit
		@ledgers = WkLedger.pluck(:name, :id)
   end
   
    def update
    end
  
   def set_filter_session
        if params[:searchlist].blank? && session[:wktransaction].nil?
			session[:wktransaction] = {:period_type => params[:period_type],:period => params[:period],			                      
								   :from => @from, :to => @to}
		elsif params[:searchlist] =='wktransaction'
			session[:wktransaction][:period_type] = params[:period_type]
			session[:wktransaction][:period] = params[:period]
			session[:wktransaction][:from] = params[:from]
			session[:wktransaction][:to] = params[:to]
		end
		
    end
   
   # Retrieves the date range based on predefined ranges or specific from/to param dates
	def retrieve_date_range
		@free_period = false
		@from, @to = nil, nil
		period_type = session[:wktransaction][:period_type]
		period = session[:wktransaction][:period]
		fromdate = session[:wktransaction][:from]
		todate = session[:wktransaction][:to]
		
		if (period_type == '1' || (period_type.nil? && !period.nil?)) 
		    case period.to_s
			  when 'today'
				@from = @to = Date.today
			  when 'yesterday'
				@from = @to = Date.today - 1
			  when 'current_week'
				@from = getStartDay(Date.today - (Date.today.cwday - 1)%7)
				@to = @from + 6
			  when 'last_week'
				@from =getStartDay(Date.today - 7 - (Date.today.cwday - 1)%7)
				@to = @from + 6
			  when '7_days'
				@from = Date.today - 7
				@to = Date.today
			  when 'current_month'
				@from = Date.civil(Date.today.year, Date.today.month, 1)
				@to = (@from >> 1) - 1
			  when 'last_month'
				@from = Date.civil(Date.today.year, Date.today.month, 1) << 1
				@to = (@from >> 1) - 1
			  when '30_days'
				@from = Date.today - 30
				@to = Date.today
			  when 'current_year'
				@from = Date.civil(Date.today.year, 1, 1)
				@to = Date.civil(Date.today.year, 12, 31)
	        end
		elsif period_type == '2' || (period_type.nil? && (!fromdate.nil? || !todate.nil?))
		    begin; @from = fromdate.to_s.to_date unless fromdate.blank?; rescue; end
		    begin; @to = todate.to_s.to_date unless todate.blank?; rescue; end
		    @free_period = true
		else
		  # default
		  # 'current_month'		
			@from = Date.civil(Date.today.year, Date.today.month, 1)
			@to = (@from >> 1) - 1
	    end    
		
		@from, @to = @to, @from if @from && @to && @from > @to

	end

end
