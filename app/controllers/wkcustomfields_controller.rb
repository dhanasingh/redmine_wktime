class WkcustomfieldsController < ApplicationController
  unloadable
  before_filter :require_login
  before_filter :check_perm_and_redirect, :only => [:index, :edit, :update, :destroy]


  def index
  set_filter_session
    wcfName = session[:wkcustomfields][:wcfName]
    cfName = session[:wkcustomfields][:cfName]
    wcfRelatedTo = session[:wkcustomfields][:wcfRelatedTo]
    wcfCrm = session[:wkcustomfields][:wcfCrm]
    wkcustomfields = nil
    if !wcfName.blank?
      wkcustomfields = WkCustomField.where("LOWER(display_as) like LOWER(?) ", "%#{wcfName}%")
    else
      wkcustomfields = WkCustomField.all
    end
    if !cfName.blank? or !wcfRelatedTo.blank? or !wcfCrm.blank?
      custom_fields = CustomField.all
      if !cfName.blank?
        custom_fields = custom_fields.where("LOWER(name) LIKE LOWER(?) ", "%#{cfName}%")
      end
      if !wcfRelatedTo.blank?
        custom_fields = custom_fields.where(type: wcfRelatedTo)
      end
      if !wcfCrm.blank?
        custom_fields = custom_fields.where(field_format: wcfCrm)
      end
      wkcustomfields = wkcustomfields.where(custom_fields_id: custom_fields.ids)
    end
    formPagination(wkcustomfields)
  end

  def edit
    @wcfEntry = nil
  	unless params[:wcf_id].blank?
  		@wcfEntry = WkCustomField.find(params[:wcf_id].to_i)
  	end
    @wkcustomfields = CustomField.where(field_format: ['company', 'wk_lead', 'crm_contact'])
  end

  def update
    errorMsg = nil
		if params[:wcf_id].blank? || params[:wcf_id].to_i == 0
			wcfObj = WkCustomField.new
		else
		    wcfObj = WkCustomField.find(params[:wcf_id].to_i)
		end
		wcfObj.display_as = params[:display_as]
	  wcfObj.custom_fields_id = params[:custom_fields_id]
    wcfObj.render_creation = params[:render_creation]
    wcfObj.allow_users_change_project = params[:allow_users_change_project]
    wcfObj.projects_id = params[:projects_id]
    wcfObj.enumerations_id = params[:enumerations_id]
    wcfObj.allow_users_change_enumeration = params[:allow_users_change_enumeration]

		unless wcfObj.valid?
			errorMsg = errorMsg.blank? ? wcfObj.errors.full_messages.join("<br>") : wcfObj.errors.full_messages.join("<br>") + "<br/>" + errorMsg
		end
		if errorMsg.nil?
			wcfObj.save
		    redirect_to :controller => controller_name,:action => 'index' , :tab => controller_name
		    flash[:notice] = l(:notice_successful_update)
		else
			flash[:error] = errorMsg
		    redirect_to :controller => controller_name, :action => 'edit', :wcf_id => wcfObj.id
		end
  end

  def destroy
    wkcustomfield = WkCustomField.find(params[:wcf_id].to_i)
    if wkcustomfield.destroy
      flash[:notice] = l(:notice_successful_delete)
    else
      flash[:error] = location.errors.full_messages.join("<br>")
    end
    redirect_back_or_default :action => 'index', :tab => params[:tab]
  end

  def check_perm_and_redirect
		unless User.current.admin? || hasSettingPerm
			render_403
			return false
		end
	end
end

def formPagination(entries)
  @entry_count = entries.count
      setLimitAndOffset()
  @wkcustomfields = entries.order(display_as: :asc, id: :asc).limit(@limit).offset(@offset)
end

def set_filter_session
  if params[:searchlist].blank? && session[:wkcustomfields].nil?
    session[:wkcustomfields] = {:cfName => params[:cfName], :wcfName => params[:wcfName], :wcfCrm => params[:wcfCrm], :wcfRelatedTo => params[:wcfRelatedTo] }
  elsif params[:searchlist] =='wkcustomfields'
    session[:wkcustomfields][:cfName] = params[:cfName]
    session[:wkcustomfields][:wcfCrm] = params[:wcfCrm]
    session[:wkcustomfields][:wcfRelatedTo] = params[:wcfRelatedTo]
    session[:wkcustomfields][:wcfName] = params[:wcfName]
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
