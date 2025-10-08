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
class WkshiftController < WkbaseController

	menu_item :wkattendance
	before_action :require_login

	def index
		entries = WkShift.all
		formPagination(entries)
	end

	def edit
		entries = nil
		set_filter_session
		departmentID =  session[controller_name].try(:[], :department_id)
		locationID =  session[controller_name].try(:[], :location_id)
		if params[:shift_id].present?
			entries = WkShift.find(params[:shift_id])
			entries = entries.shift_roles
			entries = entries.where(location_id: locationID) if locationID.present? && locationID != "0"
			entries = entries.where(department_id: departmentID) if departmentID.present? && departmentID != "0"
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
		redirect_to :controller => 'wkshift',:action => 'index' , :tab => 'wkscheduling'


	end

	def shift_role_update
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
		redirect_to :controller => 'wkshift',:action => 'index' , :tab => 'wkscheduling'
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
		filters = [:location_id, :department_id]
		super(filters, {location_id: WkLocation.default_id})
	end

end
