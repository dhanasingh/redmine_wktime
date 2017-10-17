class WkassetdepreciationController < ApplicationController
  unloadable
  include WktimeHelper
  include WkinventoryHelper
  include WkpayrollHelper
  include WkassetHelper
  include WkbillingHelper
  include WkinvoiceHelper


	def index
        @depreciation_entries = nil
        set_filter_session
        retrieve_date_range
		productId = session[:wkassetdepreciation][:product_id]
		assetId = session[:wkassetdepreciation][:inventory_item_id]
		unless params[:generate].blank? || !to_boolean(params[:generate])
			applyDepreciation(@from, @to, productId, assetId)
		else
			sqlwhere = ""
			sqlStr = getDepreciationSql
			if !productId.blank? && assetId.blank?
				sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
				sqlwhere = sqlwhere + " pit.product_id = '#{productId}' "
			else
				unless assetId.blank?
					sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
					sqlwhere = sqlwhere + " dep.inventory_item_id = '#{assetId}'  "
				end
			end
			
			if !@from.blank? && !@to.blank?			
				sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
				sqlwhere = sqlwhere + " dep.depreciation_date between '#{@from}' and '#{@to}'  "
			end
			
			unless sqlwhere.blank?
				sqlStr = sqlStr + " WHERE " + sqlwhere
			end
			findBySql(sqlStr, WkAssetDepreciation)
		end
	end
	
	def getDepreciationSql
		sqlStr = "select dep.id, dep.depreciation_date, dep.actual_amount, dep.depreciation_amount, dep.currency, ap.name as asset_name, p.name as product_name, s.shipment_date as purchase_date, iit.cost_price from wk_asset_depreciations dep LEFT OUTER JOIN wk_inventory_items iit ON iit.id = dep.inventory_item_id LEFT OUTER JOIN wk_shipments s ON s.id = iit.shipment_id LEFT OUTER JOIN wk_asset_properties ap ON ap.inventory_item_id = iit.id LEFT OUTER JOIN wk_product_items pit ON pit.id = iit.product_item_id LEFT OUTER JOIN wk_products p ON p.id = pit.product_id"
		sqlStr
	end
	def new
	end

	def edit
		depreciationId = params[:depreciation_id]
		unless depreciationId.blank?
			@depreciation = WkAssetDepreciation.find(depreciationId) 
			@asset = @depreciation.inventory_item
		end
		if to_boolean(params[:new_depreciation])
			startDate = params[:from].to_date
			endDate = params[:to].to_date
			assetId = params[:inventory_item_id].to_i
			depreciationArr = previewOrSaveDepreciation(startDate, startDate, assetId, true)
			unless depreciationArr[0].class == String
				@depreciation = depreciationArr[0]
				@asset = WkInventoryItem.find(assetId)
			else
				redirect_to :controller => controller_name,:action => 'new' , :tab => controller_name
				flash[:error] = depreciationArr[0]
			end
		end
		render :action => 'edit'
	end
	
	def update	
		if params[:depreciation_id].blank?
		  depreciation = WkAssetDepreciation.new
		else
		  depreciation = WkAssetDepreciation.find(params[:depreciation_id])
		end
		depreciation.depreciation_date = params[:depreciation_date]
		depreciation.currency = params[:currency]
		depreciation.inventory_item_id = params[:inventory_item_id]
		depreciation.actual_amount = params[:actual_amount]
		depreciation.depreciation_amount = params[:depreciation_amount]
		if depreciation.save()
			assetLedgerId = depreciation.inventory_item.product_item.product.ledger_id
			postDepreciationToAccouning(depreciation, assetLedgerId)
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
			session[:wkassetdepreciation] = {:product_id => params[:product_id], :inventory_item_id => params[:inventory_item_id],:period => params[:period], 
								   :from => @from, :to => @to}
		elsif params[:searchlist] =='wkassetdepreciation'
			session[:wkassetdepreciation][:product_id] = params[:product_id]
			session[:wkassetdepreciation][:inventory_item_id] = params[:inventory_item_id]
			session[:wkassetdepreciation][:period_type] = params[:period_type]
			session[:wkassetdepreciation][:period] = params[:period]
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
	
	def applyDepreciation(startDate, endDate, productId, assetId)
		assetIdArr = nil
		if assetId.blank? && !productId.blank?
			assetIdArr = WkInventoryItem.joins(:product_item, :asset_property).where("product_type = ? AND wk_product_items.product_id = ?", 'A', productId).pluck(:id)
		else
			assetIdArr = assetId.to_i unless assetId.blank?
		end
		depreciationArr = previewOrSaveDepreciation(startDate, endDate, assetIdArr, false)
		errorMsg = depreciationArr[0]
		if errorMsg.blank?	
			redirect_to :controller => 'wkassetdepreciation', :action => 'index' , :tab => 'wkassetdepreciation'
			flash[:notice] = l(:notice_successful_update)
		else
			redirect_to :controller => 'wkassetdepreciation', :action => 'index', :tab => 'wkassetdepreciation'
		    flash[:error] = errorMsg
		end	
	end
	
	def previewOrSaveDepreciation(startDate, endDate, assetId, isPreview)
		depreciationFreq = Setting.plugin_redmine_wktime['wktime_depreciation_frequency']
		depFreqValue = getFrequencyMonth(depreciationFreq)
		depreciationArr = Array.new 
		finacialPeriodArr = getFinancialPeriodArray(startDate, endDate, depreciationFreq)
		unless assetId.blank?
			assetEntries = WkInventoryItem.where(:id => assetId)
		else
			assetEntries = WkInventoryItem.asset.joins(:asset_property).where("wk_asset_properties.asset_type = ?", 'O')
		end
		errorMsg = ""
		localCurrency = Setting.plugin_redmine_wktime['wktime_currency']
		# depLedgerId = 28 # This value should be get from settings
		assetEntries.each do |entry|
			assetProduct = entry.product_item.product
			depreciationRate = assetProduct.depreciation_rate
			depreciationType = Setting.plugin_redmine_wktime['wktime_depreciation_type'] #assetProduct.depreciation_type
			assetLedgerId = assetProduct.ledger_id
			unless depreciationRate.blank? || depreciationType.blank?
				finacialPeriodArr.each do|finacialPeriod|
					currentAssetVal = getCurrentAssetValue(entry, finacialPeriod[1])
					assetPrice = entry.cost_price + entry.over_head_price
					#sourceAmount = depreciationType != 'SL' ? currentAssetVal : (entry.cost_price + entry.over_head_price)
					depreciationAmt = getDepreciationAmount(depreciationType, depreciationRate, depFreqValue, currentAssetVal, assetPrice)
					depreciation = WkAssetDepreciation.where(:inventory_item_id => entry.id, :depreciation_date => finacialPeriod[1]).first_or_initialize(:depreciation_date => finacialPeriod[1], :inventory_item_id => entry.id)
					depreciation.actual_amount = currentAssetVal
					depreciation.depreciation_amount = depreciationAmt
					depreciation.currency = localCurrency
					unless isPreview
						if depreciation.save
							postDepreciationToAccouning(depreciation, assetLedgerId)
							# if true #autoPostGL('depreciation') Should get from settings
								# transAmountArr = [{assetLedgerId => depreciationAmt}, {depLedgerId => depreciationAmt}]
								# transId = depreciation.gl_transaction.blank? ? nil : depreciation.gl_transaction.id
								# glTransaction = postToGlTransaction('depreciation', transId, depreciation.depreciation_date, transAmountArr, depreciation.currency, nil, nil)
								# unless glTransaction.blank?
									# depreciation.gl_transaction_id = glTransaction.id
									# depreciation.save
								# end		
							# end
						else
							errorMsg = depreciation.errors.full_messages.join('\n')		
						end
					else
						depreciationArr << depreciation
					end
				end
			end
		end
		if assetEntries[0].blank?
			errorMsg = l(:error_wktime_save_nothing)
		end
		depreciationArr << errorMsg unless errorMsg.blank? || depreciationArr[0].blank?
		depreciationArr
	end
	
	def getInventoryAssetItems(productId, productType, needBlank)
		#inventoryArr = Array.new
		# if productId.blank?
			# assetItems = WkInventoryItem.where(:product_type => productType).pluck()
		# else
		unless productId.blank?
			assetItems = WkInventoryItem.joins(:product_item, :asset_property).where("product_type = ? AND wk_product_items.product_id = ?", productType, productId).pluck("wk_asset_properties.name, wk_inventory_items.id")
		else
			assetItems = WkInventoryItem.joins(:product_item, :asset_property).where("product_type = ?", productType).pluck("wk_asset_properties.name, wk_inventory_items.id")
		end
		# end
		assetItems.unshift(["",""]) if needBlank
		assetItems
	end
	
	def postDepreciationToAccouning(depreciation, assetLedgerId)
		depLedgerId = getSettingCfId('depreciation_ledger')
		if autoPostGL('inventory') && depLedgerId > 0
			transAmountArr = [{assetLedgerId => depreciation.depreciation_amount}, {depLedgerId => depreciation.depreciation_amount}]
			transId = depreciation.gl_transaction.blank? ? nil : depreciation.gl_transaction.id
			glTransaction = postToGlTransaction('depreciation', transId, depreciation.depreciation_date, transAmountArr, depreciation.currency, nil, nil)
			unless glTransaction.blank?
				depreciation.gl_transaction_id = glTransaction.id
				depreciation.save
			end		
		end
	end

	def setLimitAndOffset		
		if api_request?
			@offset, @limit = api_offset_and_limit
			if !params[:limit].blank?
				@limit = params[:limit]
			end
			if !params[:offset].blank?
				@offset = params[:offset]
			end
		else
			@entry_pages = Paginator.new @entry_count, per_page_option, params['page']
			@limit = @entry_pages.per_page
			@offset = @entry_pages.offset
		end	
	end
	
	def findBySql(query, model)
		result = model.find_by_sql("select count(*) as id from (" + query + ") as v2")
		@entry_count = result.blank? ? 0 : result[0].id
        setLimitAndOffset()		
		rangeStr = formPaginationCondition()	
		@depreciation_entries = model.find_by_sql(query + " order by dep.depreciation_date desc, p.name asc " + rangeStr )
	end
	
	def formPaginationCondition
		rangeStr = ""
		if ActiveRecord::Base.connection.adapter_name == 'SQLServer'				
			rangeStr = " OFFSET " + @offset.to_s + " ROWS FETCH NEXT " + @limit.to_s + " ROWS ONLY "
		else		
			rangeStr = " LIMIT " + @limit.to_s +	" OFFSET " + @offset.to_s
		end
		rangeStr
	end

end
