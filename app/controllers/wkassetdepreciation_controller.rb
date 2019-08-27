class WkassetdepreciationController < WkassetController
  unloadable
  menu_item :wkproduct
  include WktimeHelper
  include WkinventoryHelper
  include WkpayrollHelper
  include WkassetHelper
  include WkbillingHelper
  include WkinvoiceHelper
  include WkassetdepreciationHelper


	def index
		sort_init 'id', 'asc'
		sort_update 'asset_name' => "asset_name",
					'product_name' => "product_name",
					'purchase_date' => "purchase_date",
					'previous_value' => "dep.actual_amount",
					'depreciation_date' => "dep.depreciation_date",
					'depreciation' => "dep.depreciation_amount"

        @depreciation_entries = nil
        set_filter_session
        retrieve_date_range
		productId = session[controller_name].try(:[], :product_id)
		assetId = session[controller_name].try(:[], :inventory_item_id)
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
			sqlStr = sqlStr + " ORDER BY " + (sort_clause.present? ? sort_clause.first : " dep.depreciation_date desc, p.name asc")
			findBySql(sqlStr, WkAssetDepreciation)
		end
	end
	
	def getDepreciationSql
		sqlStr = "select dep.id, dep.depreciation_date, dep.actual_amount, dep.depreciation_amount, dep.currency, ap.name as asset_name, p.name as product_name, s.shipment_date as purchase_date, iit.cost_price, iit.over_head_price from wk_asset_depreciations dep LEFT OUTER JOIN wk_inventory_items iit ON iit.id = dep.inventory_item_id LEFT OUTER JOIN wk_shipments s ON s.id = iit.shipment_id LEFT OUTER JOIN wk_asset_properties ap ON ap.inventory_item_id = iit.id LEFT OUTER JOIN wk_product_items pit ON pit.id = iit.product_item_id LEFT OUTER JOIN wk_products p ON p.id = pit.product_id"
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
		depreciation.actual_amount = params[:actual_amount].to_f
		depreciation.depreciation_amount = params[:depreciation_amount].to_f
		if depreciation.save()
			depreciationFreq = Setting.plugin_redmine_wktime['wktime_depreciation_frequency']
			finacialPeriodArr = getFinancialPeriodArray(depreciation.depreciation_date, depreciation.depreciation_date, depreciationFreq, 1)
			finacialPeriod = finacialPeriodArr[0]
			assetLedgerId = depreciation.inventory_item.product_item.product.ledger_id
			unless assetLedgerId.blank?
				productDepAmtHash = { assetLedgerId => depreciation.depreciation_amount}
				postDepreciationToAccouning([depreciation.id], [depreciation.gl_transaction_id], depreciation.depreciation_date, productDepAmtHash, depreciation.depreciation_amount, depreciation.currency)
			end
			WkAssetDepreciation.where(:inventory_item_id => depreciation.inventory_item_id, :depreciation_date => finacialPeriod[0] .. finacialPeriod[1]).where.not(:depreciation_date => finacialPeriod[1]).destroy_all
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
		session[controller_name] = {:from => @from, :to => @to} if session[controller_name].nil?
		if params[:searchlist] == controller_name
			filters = [:product_id, :inventory_item_id, :period_type, :period, :from, :to]
			filters.each do |param|
				if params[param].blank? && session[controller_name].try(:[], param).present?
					session[controller_name].delete(param)
				elsif params[param].present?
					session[controller_name][param] = params[param]
				end
			end
		end
	end
   
    # Retrieves the date range based on predefined ranges or specific from/to param dates
	def retrieve_date_range
		@free_period = false
		@from, @to = nil, nil
		period_type = session[controller_name].try(:[], :period_type)
		period = session[controller_name].try(:[], :period)
		fromdate = session[controller_name].try(:[], :from)
		todate = session[controller_name].try(:[], :to)
		
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
	
	def getInventoryAssetItems(productId, productType, needBlank)		
		unless productId.blank?
			assetItems = WkInventoryItem.joins(:product_item, :asset_property).where("product_type = ? AND wk_product_items.product_id = ?", productType, productId).pluck("wk_asset_properties.name, wk_inventory_items.id")
		else
			assetItems = WkInventoryItem.joins(:product_item, :asset_property).where("product_type = ?", productType).pluck("wk_asset_properties.name, wk_inventory_items.id")
		end
		assetItems.unshift(["",""]) if needBlank
		assetItems
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
		@depreciation_entries = model.find_by_sql(query + rangeStr )
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
