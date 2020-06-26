# ERPmine - ERP for service industry
# Copyright (C) 2011-2016  Adhi software pvt ltd
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

class WkbaseController < ApplicationController
	unloadable
	before_action :require_login
	before_action :clear_sort_session
	accept_api_auth :getUserPermissions
	helper :sort
	include SortHelper
	include WkattendanceHelper
	include WktimeHelper

	def index
	end
	
	def edit
	end
	
	def update
	end
	
	def destroy
	end
  
	def updateClockInOut
		lastAttnEntries = findLastAttnEntry(true)
		if !lastAttnEntries.blank?
			@lastAttnEntry = lastAttnEntries[0]
		end
		entryTime  =  Time.now
		entryTime = entryTime - (entryTime.utc_offset.seconds + (params[:offSet].to_i).minutes)
		@lastAttnEntry = saveAttendance(@lastAttnEntry, entryTime, nil, User.current.id, false)
		ret = 'done'
		respond_to do |format|
			format.text  { render :plain => ret }
		end
	end
	
	def updateAddress
		wkAddress = nil
		addressId = nil
	    if params[:address_id].blank? || params[:address_id].to_i == 0
		    wkAddress = WkAddress.new 
	    else
		    wkAddress = WkAddress.find(params[:address_id].to_i)
	    end
		# For Address table
		wkAddress.address1 = params[:address1]
		wkAddress.address2 = params[:address2]
		wkAddress.work_phone = params[:work_phone]
		wkAddress.city = params[:city]
		wkAddress.state = params[:state]
		wkAddress.pin = params[:pin]
		wkAddress.country = params[:country]
		wkAddress.fax = params[:fax]
		wkAddress.mobile = params[:mobile]
		wkAddress.email = params[:email]
		wkAddress.website = params[:website]
		wkAddress.department = params[:department]
		if isChecked('crm_save_geo_location') && params[:save_current_location].to_i  == 1
			wkAddress.longitude = params[:longitude]
			wkAddress.latitude = params[:latitude]
		end
		if wkAddress.valid?
			wkAddress.save
			addressId = wkAddress.id
		end		
		addressId
	end
	
	# Retrieves the date range based on predefined ranges or specific from/to param dates
	def retrieve_date_range
		@free_period = false
		@from, @to = nil, nil
		period_type = session[controller_name].try( :[], :period_type)
		period = session[controller_name].try( :[], :period)
		fromdate = session[controller_name].try( :[], :from)
		todate = session[controller_name].try( :[], :to)
		
		if (period_type == '1' || (period_type.nil? && !period.nil?)) 
		    case period.to_s
			  when 'today'
				@from = @to = Date.today
			  when 'yesterday'
				@from = @to = Date.today - 1
			  when 'current_week'
				@from = getStartDay(Date.today - (Date.today.cwday - 1)%7)
				@to = @from + 6
			  when 'last_week'
				@from =getStartDay(Date.today - 7 - (Date.today.cwday - 1)%7)
				@to = @from + 6
			  when '7_days'
				@from = Date.today - 7
				@to = Date.today
			  when 'current_month'
				@from = Date.civil(Date.today.year, Date.today.month, 1)
				@to = (@from >> 1) - 1
			  when 'last_month'
				@from = Date.civil(Date.today.year, Date.today.month, 1) << 1
				@to = (@from >> 1) - 1
			  when '30_days'
				@from = Date.today - 30
				@to = Date.today
			  when 'current_year'
				@from = Date.civil(Date.today.year, 1, 1)
				@to = Date.civil(Date.today.year, 12, 31)
	        end
		elsif period_type == '2' || (period_type.nil? && (!fromdate.nil? || !todate.nil?))
		    begin; @from = fromdate.to_s.to_date unless fromdate.blank?; rescue; end
		    begin; @to = todate.to_s.to_date unless todate.blank?; rescue; end
		    @free_period = true
		else		
			@from = Date.civil(Date.today.year, Date.today.month, 1)
			@to = (@from >> 1) - 1
	    end    
		
		@from, @to = @to, @from if @from && @to && @from > @to

	end

	def clear_sort_session
		session.each do |key, values|
			session.delete(key) if key.include? "_index_sort"
		end
	end

	def getUserPermissions
		wkpermissons = WkPermission.getPermissions
		respond_to do |format|
			format.json {
				permissons = (wkpermissons || []).map{ |perm| perm.short_name }
				modules = []
				Setting.plugin_redmine_wktime.each{ |key, val| modules << key.split("_")[2] if key.start_with?("wktime_enable_") && val == "1" }
				render json: { permissions: permissons, modules: modules}
			}
		end
	end

	def saveTimeLog
		entryTime = Time.now
		entryTime = entryTime - (entryTime.utc_offset.seconds + (params[:offSet].to_i).minutes)

		lastTimeEntry = WkSpentFor.lastEntry.first
		if lastTimeEntry.blank?
			project = Issue.find(params[:issue_id]).project
			activityID = project.activities.first.id
			timeEntryAttr = {
				project_id: project.id, user_id: User.current.id, issue_id: params[:issue_id], hours: 0.1, comments: l(:label_auto_populated_entry), activity_id: activityID,
				spent_on: Date.today, author_id: User.current.id, spent_for_attributes: { spent_on_time: entryTime, start_on: entryTime }
			}
			# save GeoLocation
			if isChecked('te_save_geo_location') && params[:longitude].present? && params[:latitude].present?
				timeEntryAttr[:spent_for_attributes][:s_longitude] =  params[:longitude]
				timeEntryAttr[:spent_for_attributes][:s_latitude] = params[:latitude]
			end
			timeEntry = TimeEntry.new(timeEntryAttr)
		else
			timeEntry = TimeEntry.find(lastTimeEntry.id)
			start  = DateTime.strptime(timeEntry.spent_for.start_on.to_s, "%Y-%m-%d %H:%M:%S %z").to_time
			finish = DateTime.strptime(entryTime.to_s, "%Y-%m-%d %H:%M:%S %z").to_time
			finish += 24*60*60 if finish < start
			timeEntry.hours = ((finish-start)/3600).round(2)
			timeEntry.spent_for.end_on = entryTime
			# save GeoLocation
			if isChecked('te_save_geo_location') && params[:longitude].present? && params[:latitude].present?
				timeEntry.spent_for.e_longitude = params[:longitude]
				timeEntry.spent_for.e_latitude = params[:latitude]
			end
		end
		timeEntry.save
		trackerName = timeEntry.issue.tracker.to_s + '#' + timeEntry.issue_id.to_s
		respond_to do |format|
			format.text  { render :plain => trackerName }
		end
	end

end
