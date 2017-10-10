class WkassetdepreciationController < ApplicationController
  unloadable
  include WktimeHelper
  include WkinventoryHelper
  include WkpayrollHelper
  include WkassetHelper


	def index
        @depreciation_entries = nil
        set_filter_session
        retrieve_date_range
		unless params[:generate].blank? || !to_boolean(params[:generate])
			applyDepreciation(@from, @to)
		else
			@depreciation_entries = WkAssetDepreciation.all
			
			# if !@from.blank? && !@to.blank?
				# sqlQuery = sqlQuery + " and vw.salary_date between '#{@from}' and '#{@to}'"
			# end
			
			# sqlQuery = sqlQuery + " order by u.firstname,vw.salary_date desc"
			# findBySql(sqlQuery)	
			# @total_gross = @payroll_entries.sum { |p| p.basic + p.allowance }
		end
	end

	def edit
		depreciationId = params[:depreciation_id]
		@depreciation = WkAssetDepreciation.find(depreciationId)
		render :action => 'edit'
	end
	
	def update	
		if params[:depreciation_id].blank?
		  depreciation = WkAssetDepreciation.new
		else
		  depreciation = WkAssetDepreciation.find(params[:depreciation_id])
		end
		depreciation.depreciation_date = params[:depreciation_date]
		depreciation.actual_amount = params[:actual_amount]
		depreciation.depreciation_amount = params[:depreciation_amount]
		if depreciation.save()
		    redirect_to :controller => controller_name,:action => 'index' , :tab => controller_name
		    flash[:notice] = l(:notice_successful_update)
		else
		    redirect_to :controller => controller_name,:action => 'edit' , :depreciation_id => params[:depreciation_id], :tab => controller_name
		    flash[:error] = depreciation.errors.full_messages.join("<br>")
		end
    end
	
	def destroy
		depreciation = WkAssetDepreciation.find(params[:depreciation_id])
		if depreciation.destroy
			flash[:notice] = l(:notice_successful_delete)
		else
			flash[:error] = depreciation.errors.full_messages.join("<br>")
		end
		redirect_back_or_default :action => 'index', :tab => controller_name
	end

	def set_filter_session
        if params[:searchlist].blank? && session[:wkassetdepreciation].nil?
			session[:wkassetdepreciation] = {:period_type => params[:period_type],:period => params[:period], 
								   :from => @from, :to => @to}
		elsif params[:searchlist] =='wkassetdepreciation'
			session[:wkassetdepreciation][:period_type] = params[:period_type]
			session[:wkassetdepreciation][:period] = params[:period]
			#session[:wkassetdepreciation][:group_id] = params[:group_id]
			#session[:wkassetdepreciation][:user_id] = params[:user_id]
			session[:wkassetdepreciation][:from] = params[:from]
			session[:wkassetdepreciation][:to] = params[:to]
		end
		
	end
   
    # Retrieves the date range based on predefined ranges or specific from/to param dates
	def retrieve_date_range
		@free_period = false
		@from, @to = nil, nil
		period_type = session[:wkassetdepreciation][:period_type]
		period = session[:wkassetdepreciation][:period]
		fromdate = session[:wkassetdepreciation][:from]
		todate = session[:wkassetdepreciation][:to]
		
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
	
	def applyDepreciation(startDate, endDate)
		depreciationFreq = 'a' # This value should be get from settings
		depFreqValue = getFrequencyMonth(depreciationFreq)
		finacialPeriodArr = getFinancialPeriodArray(startDate, endDate, depreciationFreq)
		assetEntries = WkInventoryItem.asset.all
		errorMsg = ""
		assetEntries.each do |entry|
			depreciationRate = entry.product_item.product.depreciation_rate
			unless depreciationRate.blank?
				finacialPeriodArr.each do|finacialPeriod|
					depreciationType = entry.product_item.product.depreciation_type
					sourceAmount = depreciationType != 'SL' ? getCurrentAssetValue(entry) : (entry.cost_price + entry.over_head_price)
					depreciationAmt = (depreciationRate/12) * sourceAmount * (depFreqValue +1)
					depreciation = WkAssetDepreciation.where(:inventory_item_id => entry.id, :depreciation_date => finacialPeriod[1]).first_or_initialize(:depreciation_date => finacialPeriod[1], :inventory_item_id => entry.id)
					depreciation.actual_amount = sourceAmount
					depreciation.depreciation_amount = depreciationAmt
					unless depreciation.save
						errorMsg = depreciation.errors.full_messages.join('\n')
					end
				end
			end
		end
		if assetEntries[0].blank?
			errorMsg = l(:error_wktime_save_nothing)
		end
		if errorMsg.blank?	
			redirect_to :controller => 'wkassetdepreciation', :action => 'index' , :tab => 'wkassetdepreciation'
			flash[:notice] = l(:notice_successful_update)
		else
			redirect_to :controller => 'wkassetdepreciation', :action => 'index', :tab => 'wkassetdepreciation'
		    flash[:error] = errorMsg
		end	
	end

end
