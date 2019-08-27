class WkunitofmeasurementController < WkinventoryController
  unloadable
  before_action :require_login
  menu_item :wkproduct
  
  def index
		entries = WkMesureUnit.all	
		formPagination(entries)
	end

	def update
		count = 0		
		errorMsg = ""
		arrId = Array.new
		unless params[:actual_ids].blank?
			arrId = params[:actual_ids].split(",").map { |s| s.to_i } 
		end
		for i in 0..params[:uom_id].length-1
			if params[:uom_id][i].blank?
				curExchanges = WkMesureUnit.new
			else
				curExchanges = WkMesureUnit.find(params[:uom_id][i].to_i)
				arrId.delete(params[:uom_id][i].to_i)
			end
			curExchanges.name = params[:name][i]
			curExchanges.short_desc = params[:description][i]
			curExchanges.save()			
		end
		
		if !arrId.blank?			
			arrId.each do |id|
				des = WkMesureUnit.find(id)
				if des.destroy
					count = count + 1	
				else
					errorMsg = errorMsg + des.errors.full_messages.join("<br>")
				end
			end
			
		end
		
		redirect_to :controller => 'wkunitofmeasurement',:action => 'index' , :tab => 'wkunitofmeasurement'
		flash[:notice] = l(:notice_successful_update)
		flash[:error] = errorMsg unless errorMsg.blank?
	end
	
	def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		@curentry = entries.limit(@limit).offset(@offset)
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

end
