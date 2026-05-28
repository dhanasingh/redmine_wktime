class WkgrouppermissionController < ApplicationController

  menu_item :wkcrmenumeration
  include WktimeHelper
  before_action :check_permission_tab_and_redirect, :only => [:index, :edit, :update]

	def index
		@groups =  nil
		# entries = Group.sorted
		# entries = entries.like(params[:name]) if params[:name].present?
		# formPagination(entries)
		@groupPermission = nil
		@permission = WkPermission.order(:modules, :id)
		@groups = Group.all.sort
		#@group = Group.find(params[:filter_group_id].to_i)
		@groupPermission = WkGroupPermission.where(:group_id => params[:group_id].to_i) unless params[:group_id].blank?

		@locations_tree, @location_depths, @location_ancestor_ids =
			WkLocation.tree_ordered_by_name
		@group_location_ids =
			if params[:group_id].present?
				WkGrpLocPermission.where(group_id: params[:group_id].to_i).pluck(:location_id).to_set
			else
				Set.new
			end
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

	def update
		group_id = params[:group_id].to_i
		arrId = WkGroupPermission.where(:group_id => group_id).pluck(:id)
		for i in 1..params[:count].to_i
			if !params["is_permission#{i}"].blank? && params["is_permission#{i}"].to_i == 1
				grpPermObj = WkGroupPermission.where(:group_id => group_id, :permission_id => params["permission_id#{i}"].to_i).first_or_initialize(:group_id => group_id, :permission_id => params["permission_id#{i}"].to_i)
				if grpPermObj.save
					arrId.delete(grpPermObj.id)
				end
			end
		end

		unless arrId.blank?
			WkGroupPermission.where(:id => arrId).delete_all()
		end

		# Location access selections (submitted by the same form via form="query_form" attr on the modal's checkboxes).
		if group_id > 0
			submitted_locations = (params[:location_ids] || []).map(&:to_i).uniq
			# Store only the top-most checked node of each path: drop any location
			# whose parent is also checked (it's covered by the parent's subtree).
			submitted_set = submitted_locations.to_set
			parent_of = WkLocation.where(id: submitted_locations).pluck(:id, :parent_id).to_h
			top_locations = submitted_locations.reject { |lid| submitted_set.include?(parent_of[lid]) }
			WkGrpLocPermission.transaction do
				WkGrpLocPermission.where(group_id: group_id).delete_all
				top_locations.each do |lid|
					WkGrpLocPermission.create!(group_id: group_id, location_id: lid)
				end
			end
		end

		redirect_to :controller => 'wkgrouppermission',:action => 'index' , :tab => 'wkgrouppermission', :group_id => group_id
		flash[:notice] = l(:notice_successful_update)
	end

	def check_permission_tab_and_redirect
		unless (User.current.admin) || validateERPPermission("ADM_ERP")
			render_403
			return false
		end
	end

end
