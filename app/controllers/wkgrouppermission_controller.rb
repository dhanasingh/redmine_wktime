class WkgrouppermissionController < ApplicationController
  unloadable



	def index
		@groups =  nil
		entries = Group.sorted
		entries = entries.like(params[:name]) if params[:name].present?
		formPagination(entries)
	end
  
	def formPagination(entries)
		@entry_count = entries.count
		setLimitAndOffset()
		@groups = entries.limit(@limit).offset(@offset)
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
