# ERPmine - ERP for service industry
# Copyright (C) 2011-2020  Adhi software pvt ltd
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
	accept_api_auth :getUserPermissions, :updateClockInOut
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
			format.api{ render :plain => ret }
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
		settings = {}
		respond_to do |format|
			format.json {
				permissons = (wkpermissons || []).map{ |perm| perm.short_name }
				Setting.plugin_redmine_wktime.each.each{ |key, val| settings[key] = val if val != "" }
				configs = { 
					permissions: permissons, mapAPIkey: Setting.plugin_redmine_wktime['label_mapbox_apikey'],
					logEditPermission: getEditLogPermission,
					settings: settings
				}
				render json: configs
			}
		end
	end	

	def saveIssueTimeLog
		entryTime = get_current_DateTime
		if params[:issue_id].present?
			project = Issue.find(params[:issue_id]).project
			activityID = project.activities.first.id
			timeEntryAttr = {
				project_id: project.id, user_id: User.current.id, issue_id: params[:issue_id], hours: 0.1, activity_id: activityID,
				spent_on: Date.today, author_id: User.current.id, spent_for_attributes: { spent_on_time: entryTime, clock_action: "S" }
			}
			# save GeoLocation
			if isChecked('te_save_geo_location') && params[:longitude].present? && params[:latitude].present?
				timeEntryAttr[:spent_for_attributes][:s_longitude] =  params[:longitude]
				timeEntryAttr[:spent_for_attributes][:s_latitude] = params[:latitude]
			end
			timeEntry = TimeEntry.new(timeEntryAttr)
			timeEntry.save
		else
			wkSpentFor = WkSpentFor.find(params[:id])
			if(wkSpentFor.spent_type == "TimeEntry")
				timeEntry = TimeEntry.find(wkSpentFor.spent_id)
				start  = DateTime.strptime(timeEntry.spent_for.spent_on_time.to_s, "%Y-%m-%d %H:%M:%S %z").to_time
				finish = DateTime.strptime(entryTime.to_s, "%Y-%m-%d %H:%M:%S %z").to_time
				timeEntry.hours = ((finish-start)/3600).round(2)
				timeEntry.spent_for.end_on = entryTime
				timeEntry.spent_for.clock_action = "E"
				# save GeoLocation
				if isChecked('te_save_geo_location') && params[:longitude].present? && params[:latitude].present?
					timeEntry.spent_for.e_longitude = params[:longitude]
					timeEntry.spent_for.e_latitude = params[:latitude]
				end
				timeEntry.save
			else
				materialEntry = WkMaterialEntry.find(wkSpentFor.spent_id)
				quantity = getAssetQuantity(materialEntry.spent_for.spent_on_time, entryTime, materialEntry.inventory_item_id)
				materialEntry.quantity = quantity
				materialEntry.spent_for.end_on = entryTime
				materialEntry.spent_for.clock_action = "E"
				# save GeoLocation
				if isChecked('te_save_geo_location') && params[:longitude].present? && params[:latitude].present?
					materialEntry.spent_for.e_longitude = params[:longitude]
					materialEntry.spent_for.e_latitude = params[:latitude]
				end
				unless materialEntry.valid?
					renderMsg = materialEntry.errors.full_messages.join("<br>")
				else
					materialEntry.save
				end
				inventoryObj = WkInventoryItem.find(materialEntry.inventory_item_id)
				assetObj = inventoryObj.asset_property
				assetObj.matterial_entry_id = nil
				assetObj.save
			end
		end
		lastIssueLog = WkSpentFor.getIssueLog.first
		renderMsg = lastIssueLog.blank? ? "start" : "finish" if renderMsg.blank?
		respond_to do |format|
			format.text  { render(js: renderMsg) }
		end
	end

	def findCountBySql(query, model)
		result = model.find_by_sql("select count(*) as counts " + query)
	  return result.blank? ? 0 : result[0].counts
	end

	def findSumBySql(query, sumfield, model)
		result = model.find_by_sql("select sum("+sumfield+") as total " + query)
		return result.blank? ? 0 : result[0].total
	end

	def set_filter_session(filters)
		if params[:searchlist] == controller_name
			session[controller_name] = Hash.new if session[controller_name].nil?
			filters.each do |param|
				if params[param].blank? && session[controller_name].try(:[], param).present?
					session[controller_name].delete(param)
				elsif params[param].present?
					session[controller_name][param] = params[param]
				end
			end
		end
	end

	def getSession(key)
		return session[controller_name].present? ? session[controller_name][key] : nil
	end

	def list_to_pdf(listEntries, title)
		pdf = ITCPDF.new(current_language)
		pdf.SetTitle(title)
		pdf.add_page

		page_width    = pdf.get_page_width
		left_margin   = pdf.get_original_margins['left']
		right_margin  = pdf.get_original_margins['right']
		table_width = page_width - right_margin - left_margin
		row_Height = 8
		pdf.SetFontStyle('B', 12)
		pdf.RDMMultiCell(table_width, row_Height, title, 0, 'C', 0, 1)

		pdf.SetFontStyle('B', 9)
		pdf.set_fill_color(230, 230, 230)
		headers = getPDFHeaders()
		headers.each{ |h| pdf.RDMCell(h.last, row_Height, h.first, 1, 0, '', 1) }
		pdf.ln

		pdf.SetFontStyle('', 8)
		listEntries.each do |entry|
			list = getPDFcells(entry)
			list.each{ |h| pdf.RDMCell(h.last, row_Height, h.first, 1, 0, '', 0) }
			pdf.ln
		end
		pdf.SetFontStyle('B', 9)
		getPDFFooter(pdf, row_Height)
		pdf.Output
	end
end
