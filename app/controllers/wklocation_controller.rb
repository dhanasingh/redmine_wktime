class WklocationController < WkbaseController
  unloadable
  include WktimeHelper
  before_filter :require_login
  before_filter :check_perm_and_redirect, :only => [:index, :edit, :update, :destroy]


  def index
	set_filter_session
		locationName = session[:wklocation][:locName]		
		locationType =  session[:wklocation][:locType]
		wklocation = nil
		if !locationName.blank? &&  !locationType.blank? && locationType.to_i != 0
			wklocation = WkLocation.where(:location_type_id => locationType.to_i).where("LOWER(name) like LOWER(?) ", "%#{locationName}%")
		elsif locationName.blank? &&  !locationType.blank? && locationType.to_i != 0
			wklocation = WkLocation.where(:location_type_id => locationType.to_i)
		elsif !locationName.blank? &&  (locationType.blank? ||  locationType.to_i == 0 )
			wklocation = WkLocation.where("LOWER(name) like LOWER(?) ", "%#{locationName}%")
		else
			wklocation = WkLocation.all
		end	
		formPagination(wklocation)
  end
  
  def edit
	@locEntry = nil
	unless params[:location_id].blank?
		@locEntry = WkLocation.find(params[:location_id])
	end
  end
  
  def update
		errorMsg = nil
		if params[:location_id].blank? || params[:location_id].to_i == 0
			locationObj = WkLocation.new
		else
		    locationObj = WkLocation.find(params[:location_id].to_i)
		end
		locationObj.name = params[:location_name]
		locationObj.location_type_id = params[:location_type]
		locationObj.is_default = params[:defaultValue]
		unless locationObj.valid? 		
			errorMsg = errorMsg.blank? ? locationObj.errors.full_messages.join("<br>") : locationObj.errors.full_messages.join("<br>") + "<br/>" + errorMsg
		end
		if errorMsg.nil?
			addrId = updateAddress
			unless addrId.blank?
				locationObj.address_id = addrId
			end			
			locationObj.save
		    redirect_to :controller => controller_name,:action => 'index' , :tab => controller_name
		    flash[:notice] = l(:notice_successful_update)
		else
			flash[:error] = errorMsg 
		    redirect_to :controller => controller_name,:action => 'edit', :location_id => locationObj.id
		end
  end
  
  def destroy
		location = WkLocation.find(params[:location_id].to_i)
		if location.destroy
			flash[:notice] = l(:notice_successful_delete)
		else
			flash[:error] = location.errors.full_messages.join("<br>")
		end
		redirect_back_or_default :action => 'index', :tab => params[:tab]
  end

  def set_filter_session
        if params[:searchlist].blank? && session[:wklocation].nil?
			session[:wklocation] = {:locName => params[:location_name], :locType => params[:location_type] }
		elsif params[:searchlist] =='wklocation'
			session[:wklocation][:locName] = params[:location_name]
			session[:wklocation][:locType] = params[:location_type]
		end
		
    end
	
	def check_perm_and_redirect
		unless User.current.admin? || hasSettingPerm
			render_403
			return false
		end
	end
	
	def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		@locationObj = entries.order(location_type_id: :asc, name: :asc).limit(@limit).offset(@offset)
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
