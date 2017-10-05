class WkpermissionController < ApplicationController
  unloadable
  
  
  accept_api_auth :index, :add_permission, :remove_permission

  require_sudo_mode :add_permission, :remove_permission

 include WkpermissionHelper

  def index
  end
  
  def new_permission
  end
  
  def add_permission
    @group = Group.find(params[:id].to_i)
	unless params[:permission_ids].blank?
		for i in 0..params[:permission_ids].length-1 
			@groupPermissionObj = WkGroupPermission.new
			@groupPermissionObj.permission_id = params[:permission_ids][i]
			@groupPermissionObj.group_id = params[:id].to_i
			@groupPermissionObj.save
		end
	end
    @permission = WkPermission.all
	
    respond_to do |format|
      format.html { redirect_to edit_group_path(@group, :tab => 'permission') }
      format.js
      format.api {
        if @users.any?
          render_api_ok
        else
          render_api_errors "#{l(:label_user)} #{l('activerecord.errors.messages.invalid')}"
        end
      }
    end
  end
  
  def remove_permission
    @group = Group.find(params[:group_id].to_i)
    #@group.group_permissions.delete(WkGroupPermission.find(params[:permission_id].to_i)) if request.delete?
    WkGroupPermission.find(params[:permission_id]).delete() if request.delete?
    respond_to do |format|
      format.html { redirect_to new_group_permission } #redirect_to edit_group_path(@group, :tab => 'permission')
      format.js
      format.api { render_api_ok }
    end
  end
  
  def autocomplete_for_permission
    respond_to do |format|
      format.js
    end
  end

end
