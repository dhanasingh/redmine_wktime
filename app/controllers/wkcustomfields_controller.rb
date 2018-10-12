class WkcustomfieldsController < ApplicationController
  unloadable
  before_filter :require_login
  before_filter :check_perm_and_redirect, :only => [:index, :edit, :update, :destroy]


  def index
    @wkcustomfields = WkCustomField.all
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
		wcfObj.custom_fields_id = params[:custom_field_id].to_i
		unless wcfObj.valid?
			errorMsg = errorMsg.blank? ? wcfObj.errors.full_messages.join("<br>") : wcfObj.errors.full_messages.join("<br>") + "<br/>" + errorMsg
		end
		if errorMsg.nil?
			wcfObj.save
		    redirect_to :controller => controller_name,:action => 'index' , :tab => controller_name
		    flash[:notice] = l(:notice_successful_update)
		else
			flash[:error] = errorMsg
		    redirect_to :controller => controller_name,:action => 'edit', :id => wcfObj.id
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
