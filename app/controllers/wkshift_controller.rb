# ERPmine - ERP for service industry
# Copyright (C) 2011-2018  Adhi software pvt ltd
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
class WkshiftController < ApplicationController
  unloadable
	menu_item :wkattendance
	before_action :require_login



	def index
		entries = WkShift.all	
		formPagination(entries)
	end
	
	def edit
		entries = nil
		set_filter_session
		departmentId =  session[controller_name].try(:[], :department_id)
		locationId =  session[controller_name].try(:[], :location_id)
		unless params[:shift_id].blank?
			@shiftObj = WkShift.find(params[:shift_id].to_i)			
			if (!departmentId.blank? && departmentId.to_i != 0 ) && !locationId.blank?
				entries = @shiftObj.shift_roles.where(:department_id => departmentId.to_i, :location_id => locationId.to_i)
			elsif (!departmentId.blank? && departmentId.to_i != 0 ) && locationId.blank?
				entries = @shiftObj.shift_roles.where(:department_id => departmentId.to_i, :location_id => nil)
			elsif (departmentId.blank? || departmentId.to_i == 0 ) && !locationId.blank?
				entries = @shiftObj.shift_roles.where(:location_id => locationId.to_i, :department_id => nil)
			else
				entries = @shiftObj.shift_roles.where(:location_id => nil, :department_id => nil)
			end
			formPagination(entries)
		end
	end

	def update
		count = 0		
		errorMsg = ""
		arrId = WkShift.all.pluck(:id)
		for i in 0..params[:shift_id].length-1
			if params[:shift_id][i].blank?
				shiftEntries = WkShift.new
			else
				shiftEntries = WkShift.find(params[:shift_id][i].to_i)
				arrId.delete(params[:shift_id][i].to_i)
			end
			shiftEntries.name = params[:name][i]
			shiftEntries.start_time = params[:start_time][i]
			shiftEntries.end_time = params[:end_time][i]
			shiftEntries.in_active = params[:inactive][i] unless params[:inactive].blank?
			shiftEntries.is_schedulable = params[:isschedulable][i] unless params[:isschedulable].blank?
			if shiftEntries.new_record?
				shiftEntries.created_by_user_id = User.current.id
			end
			shiftEntries.updated_by_user_id = User.current.id
			if shiftEntries.save()
				#arrId << shiftEntries.id
				arrId.delete(shiftEntries.id)
			else
				errorMsg =  timeEntries.errors.full_messages.join("<br>")
			end
		end
		#WkShift.where(:id => arrId).delete_all()
		if !arrId.blank?
			arrId.each do | id |
				shiftDes = WkShift.find(id.to_i)
				unless shiftDes.destroy
					errorMsg = shiftDes.errors.full_messages.join("<br>")
				end
			end
		end
		unless errorMsg.blank?
			flash[:error] = errorMsg 
		else
			flash[:notice] = l(:notice_successful_update)
		end
		redirect_to :controller => 'wkshift',:action => 'index' , :tab => 'wkshift'
		
		
	end
	
	def shiftRoleUpdate
		count = 0		
		errorMsg = ""
		unless params[:actual_ids].blank?
			arrId = params[:actual_ids].split(",").map { |s| s.to_i } 
		end
		for i in 0..params[:shift_role_id].length-1
			if params[:shift_role_id][i].blank?
				shiftRoleEntries = WkShiftRole.new
			else
				shiftRoleEntries = WkShiftRole.find(params[:shift_role_id][i].to_i)
				arrId.delete(params[:shift_role_id][i].to_i)
			end
			shiftRoleEntries.role_id = params[:role_id][i].to_i
			shiftRoleEntries.shift_id = params[:shift_id].to_i
			shiftRoleEntries.staff_count = params[:staff_count][i].to_i
			shiftRoleEntries.location_id = params[:location_id] if params[:location_id] != "0"
			shiftRoleEntries.department_id = params[:department_id].to_i == 0 ? nil : params[:department_id].to_i 
			if shiftRoleEntries.new_record?
				shiftRoleEntries.created_by_user_id = User.current.id
			end
			shiftRoleEntries.updated_by_user_id = User.current.id
			unless shiftRoleEntries.save()
				errorMsg =  timeEntries.errors.full_messages.join("<br>")
			end
		end
		WkShiftRole.where(:id => arrId).delete_all()
				
		unless errorMsg.blank?
			flash[:error] = errorMsg 
		else
			flash[:notice] = l(:notice_successful_update)
		end
		redirect_to :controller => 'wkshift',:action => 'index' , :tab => 'wkshift'		
	end
	
	def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		@shiftentry = entries.limit(@limit).offset(@offset)
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
	
	def set_filter_session
		if params[:searchlist] == controller_name
			session[controller_name] = Hash.new if session[controller_name].nil?
			filters = [:location_id, :department_id]
			filters.each do |param|
				if params[param].blank? && session[controller_name].try(:[], param).present?
					session[controller_name].delete(param)
				elsif params[param].present?
					session[controller_name][param] = params[param]
				end
			end
		end
	end

end
