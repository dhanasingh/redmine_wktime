class WkgrouppermissionController < ApplicationController
  unloadable
  include WktimeHelper
  before_action :check_permission_tab_and_redirect, :only => [:index, :edit, :update]

	def index
		@groups =  nil
		# entries = Group.sorted
		# entries = entries.like(params[:name]) if params[:name].present?
		# formPagination(entries)
		@groupPermission = nil
		@permission = WkPermission.order(:modules)
		@groups = Group.all.sort
		#@group = Group.find(params[:filter_group_id].to_i)
		@groupPermission = WkGroupPermission.where(:group_id => params[:group_id].to_i) unless params[:group_id].blank?
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
	
	def edit
		@groupPermission = nil
		@permission = WkPermission.order(:modules)
		@group = Group.find(params[:group_id].to_i)
		@groupPermission = WkGroupPermission.where(:group_id => params[:group_id].to_i) unless params[:group_id].blank?
	end
	
	def update
		arrId = WkGroupPermission.where(:group_id => params[:group_id].to_i).pluck(:id)
		for i in 1..params[:count].to_i
			if !params["is_permission#{i}"].blank? && params["is_permission#{i}"].to_i == 1
				grpPermObj = WkGroupPermission.where(:group_id => params[:group_id].to_i, :permission_id => params["permission_id#{i}"].to_i).first_or_initialize(:group_id => params[:group_id].to_i, :permission_id => params["permission_id#{i}"].to_i)				
				if grpPermObj.save
					arrId.delete(grpPermObj.id)
				end
			end			
		end
		
		unless arrId.blank?
			WkGroupPermission.where(:id => arrId).delete_all()
		end
		
		redirect_to :controller => 'wkgrouppermission',:action => 'index' , :tab => 'wkgrouppermission', :group_id => params[:group_id].to_i			
		flash[:notice] = l(:notice_successful_update)
	end
	
	def check_permission_tab_and_redirect
		unless (User.current.admin) || validateERPPermission("ADM_ERP")
			render_403
			return false
		end
	end

end
