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
class WkpublicholidayController < ApplicationController
  unloadable
  menu_item :wkattendance
  
	def index
		@year ||= User.current.today.year
		@month ||= User.current.today.month
		if params[:year] and params[:year].to_i > 1900
			@year = params[:year].to_i
			if params.key?("month")
				@month = params[:month].to_i
			end
		end
		
		location = WkLocation.where(:is_default => 'true').first
		locationId = !params[:location_id].blank? ?  params[:location_id] : (location.blank? ? nil : location.id)
		
		entries = WkPublicHoliday.all
		if locationId == "0"
			entries = WkPublicHoliday.where(location_id: nil)
		elsif !locationId.blank? && !(["0", "All"].include? locationId)
			entries = WkPublicHoliday.where(:location_id => locationId)
		end
		@locationId = locationId.blank? ? "All" :  locationId
		if !params[:month].blank? || @month > 0
			calendar = Redmine::Helpers::Calendar.new(Date.civil(@year, @month, 1), current_language, :month)
			entries = entries.where(:holiday_date => calendar.startdt..calendar.enddt)
		else			
			unless params[:year].blank?
				@year_from = params[:year].to_i	
			else				
				@year_from ||= User.current.today.year 
			end
			startMonth = Date.civil(@year_from, 1, 1)
			endMonth = Date.civil(@year_from, 12, 1)
			entries = entries.where(:holiday_date => startMonth..(endMonth+30))
		end
		entries = entries.order(:holiday_date)
		formPagination(entries)
	end
	
	
	def update
		count = 0		
		errorMsg = ""
		arrId = Array.new
		unless params[:actual_ids].blank?
			arrId = params[:actual_ids].split(",").map { |s| s.to_i } 
		end
		for i in 0..params[:ph_id].length-1
			if params[:ph_id][i].blank?
				publicHoliday = WkPublicHoliday.new
			else
				publicHoliday = WkPublicHoliday.find(params[:ph_id][i].to_i)
				arrId.delete(params[:ph_id][i].to_i)
			end
			publicHoliday.holiday_date = params[:holiday_date][i]
			publicHoliday.location_id = params[:location_id][i] == "0" ? nil : params[:location_id][i]
			publicHoliday.description = params[:description][i]
			if publicHoliday.new_record?
				publicHoliday.created_by_user_id = User.current.id
			end
			publicHoliday.updated_by_user_id = User.current.id
			publicHoliday.save()			
		end
		
		if !arrId.blank?			
			arrId.each do |id|
				des = WkPublicHoliday.find(id)
				if des.destroy
					count = count + 1	
				else
					errorMsg = errorMsg + des.errors.full_messages.join("<br>")
				end
			end
			
		end
		
		redirect_to :controller => 'wkpublicholiday',:action => 'index' , :tab => 'wkpublicholiday'
		flash[:notice] = l(:notice_successful_update)
		flash[:error] = errorMsg unless errorMsg.blank?
	end
	
	def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()		
		@phEntry = entries.limit(@limit).offset(@offset)
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
