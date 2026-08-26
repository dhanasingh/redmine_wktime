# ERPmine - ERP for service industry
# Copyright (C) 2011-  Adhi software pvt ltd
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

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
