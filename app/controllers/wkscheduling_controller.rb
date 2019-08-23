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
class WkschedulingController < WkbaseController
  unloadable
  menu_item :wkattendance
  before_action :require_login  
  rescue_from Query::StatementInvalid, :with => :query_statement_invalid

  helper :issues
  helper :projects
  helper :queries
  include QueriesHelper
  include WktimeHelper
  include WkschedulingHelper


	def index	
		@schedulesShift = validateERPPermission("S_SHIFT")
		@editShiftSchedules = validateERPPermission("E_SHIFT")
		@year ||= User.current.today.year
		@month ||= User.current.today.month
		if params[:year] and params[:year].to_i > 1900
			@year = params[:year].to_i
			if params[:month] and params[:month].to_i > 0 and params[:month].to_i < 13
				@month = params[:month].to_i
			end
		end
		
		
		@calendar = Redmine::Helpers::Calendar.new(Date.civil(@year, @month, 1), current_language, :month)
		userIds = schedulingFilterValues 
		shiftId = session[controller_name].try(:[], :shift_id)
		dayOff = session[controller_name].try(:[], :day_off)
		departmentId =  session[controller_name].try(:[], :department_id)
		locationId =  session[controller_name].try(:[], :location_id)
		startDt = @calendar.startdt
		# get start date of the  first full week of the given month
		if @month != @calendar.startdt.month
			startDt = @calendar.startdt + 7.days
		end
		unless params[:generate].blank? || !to_boolean(params[:generate])
			@locationDept.each do | entry |
				#ScheduleStrategy.new.schedule('P', entry.location_id, entry.department_id, startDt, @calendar.enddt)
				ScheduleStrategy.new.schedule('RR', entry.location_id, entry.department_id, startDt, @calendar.enddt)
			end
			flash[:notice] = l(:notice_successful_update)
			redirect_to :controller => controller_name,:action => 'index', :year => @year, :month => @month, :shift_id => shiftId, :day_off => dayOff, :department_id => departmentId, :location_id => locationId, :searchlist => "wkscheduling", :tab =>"wkscheduling", :generate => false
		end
		if !shiftId.blank?
			@shiftObj = WkShiftSchedule.where(:schedule_date => @calendar.startdt..@calendar.enddt, :user_id => userIds, :shift_id => shiftId.to_i, :schedule_type => 'S').order(:schedule_date, :user_id, :shift_id)
		elsif !userIds.blank? && userIds != 0
			@shiftObj = WkShiftSchedule.where(:schedule_date => @calendar.startdt..@calendar.enddt, :user_id => userIds, :schedule_type => 'S').order(:schedule_date, :user_id, :shift_id)
		else
			@shiftObj = WkShiftSchedule.where(:schedule_date => @calendar.startdt..@calendar.enddt, :schedule_type => 'S').order(:schedule_date, :user_id, :shift_id)
		end
		
		@shiftPreference = WkShiftSchedule.where(:schedule_date => @calendar.startdt..@calendar.enddt, :user_id => userIds, :schedule_type => 'P').order(:schedule_date, :user_id, :shift_id)
		unless dayOff.blank?
			@shiftObj = @shiftObj.where(:schedule_as => dayOff)
			@shiftPreference = @shiftPreference.where(:schedule_as => dayOff)
		end
		day = @calendar.startdt
		@schedulehash = Hash.new 
		while day <= @calendar.enddt
			arr = []
			isScheduled = false
			@shiftObj.each do |entry|
				if entry.schedule_date == day
					isScheduled = true
					arr << ((entry.user.name.to_s) + " - " + (entry.shift.blank? ? "" : entry.shift.name.to_s) +" - "+ (entry.schedule_as.to_s) +" - "+ (entry.schedule_type.to_s))				
				end
			end
			if !isScheduled && isChecked('wk_user_schedule_preference')
				@shiftPreference.each do |entry|
					if entry.schedule_date == day
						arr << ((entry.user.name.to_s) + " - " + (entry.shift.blank? ? "" : entry.shift.name.to_s) +" - "+ (entry.schedule_as.to_s)+" - "+ (entry.schedule_type.to_s))
					end
				end
			end					
			@schedulehash["#{day}"] = arr
			day = day + 1
		end 
	end
	
	def edit	
		@schedulesShift = validateERPPermission("S_SHIFT")
		@editShiftSchedules = validateERPPermission("E_SHIFT")					
		userIds = schedulingFilterValues
		scheduleDate =  params[:date]
		shiftId = session[controller_name].try(:[], :shift_id)
		dayOff = session[controller_name].try(:[], :day_off)
		@isScheduled = false
		if params[:schedule_type].to_s == 'S'
			@isScheduled = true
		end
		if !scheduleDate.blank? && !shiftId.blank? && !userIds.blank? && userIds != 0
			@shiftObj = WkShiftSchedule.where(:schedule_date => scheduleDate, :user_id => userIds, :shift_id => shiftId.to_i, :schedule_type => 'S').order(:schedule_date, :user_id) 
			@shiftPreference = WkShiftSchedule.where(:schedule_date => scheduleDate, :user_id => userIds, :shift_id => shiftId.to_i, :schedule_type => 'P').order(:schedule_date, :user_id)
		elsif !scheduleDate.blank? && shiftId.blank? 
			if @schedulesShift && @editShiftSchedules
				if !userIds.blank? && userIds != 0
					@shiftObj = WkShiftSchedule.where(:schedule_date => scheduleDate, :user_id => userIds, :schedule_type => 'S').order(:schedule_date, :user_id) 
					@shiftPreference = WkShiftSchedule.where(:schedule_date => scheduleDate, :user_id => userIds,  :schedule_type => 'P').order(:schedule_date, :user_id)
				# else
					# @shiftObj = WkShiftSchedule.where(:schedule_date => scheduleDate, :schedule_type => 'S').order(:schedule_date, :user_id) 
					# @shiftPreference = WkShiftSchedule.where(:schedule_date => scheduleDate,  :schedule_type => 'P').order(:schedule_date, :user_id)
				end
			else
				@shiftObj = WkShiftSchedule.where(:schedule_date => scheduleDate, :user_id => User.current.id, :schedule_type => 'S').order(:schedule_date, :user_id) 
				@shiftPreference = WkShiftSchedule.where(:schedule_date => scheduleDate, :user_id => User.current.id,  :schedule_type => 'P').order(:schedule_date, :user_id)
			end
		end	
		unless dayOff.blank?
			@shiftObj = @shiftObj.where(:schedule_as => dayOff)
			@shiftPreference = @shiftPreference.where(:schedule_as => dayOff)
		end	
		unless @shiftObj.blank?
			@isScheduled = true
		end
	end
	
	def update
		errorMsg = ""
		@schedulingEntries = nil
		for i in 1..params[:rowCount].to_i-1
			if to_boolean(params[:isscheduled])
				@schedulingEntries = WkShiftSchedule.where(:schedule_date => params["scheduling_date#{i}"], :user_id => params["user_id#{i}"], :schedule_type => 'S').first_or_initialize(:schedule_date => params["scheduling_date#{i}"], :user_id => params["user_id#{i}"], :schedule_type => 'S')
				if params["day_off#{i}"] == "1" 
					@schedulingEntries.schedule_as = 'O'
				else
					@schedulingEntries.schedule_as = 'W'
				end
			else
				@schedulingEntries = WkShiftSchedule.where(:schedule_date => params["scheduling_date#{i}"], :user_id => params["user_id#{i}"], :schedule_type => 'P').first_or_initialize(:schedule_date => params["scheduling_date#{i}"], :user_id => params["user_id#{i}"], :schedule_type => 'P')
				if params["day_off#{i}"] == "1"
					@schedulingEntries.schedule_as = 'O'
				elsif params["user_id#{i}"].to_i == User.current.id
					@schedulingEntries.schedule_as = 'W'
				end	
			end			
			@schedulingEntries.shift_id = params["shifts#{i}"]
			if @schedulingEntries.valid?
				if @schedulingEntries.schedule_type == "P"	
					from = getStartDay(@schedulingEntries.schedule_date)
					to = from + 6.days
					from.upto(to) do |schDt|
						unless schDt == @schedulingEntries.schedule_date
							dupSchedule = WkShiftSchedule.where(:schedule_date => schDt, :user_id => params["user_id#{i}"], :schedule_type => 'P').first_or_initialize(:schedule_date => schDt, :user_id => params["user_id#{i}"], :schedule_type => 'P')
							dupSchedule.shift_id = @schedulingEntries.shift_id
							if dupSchedule.new_record?
								dupSchedule.created_by_user_id = User.current.id
							end
							dupSchedule.updated_by_user_id = User.current.id
							dupSchedule.save 
						end
					end
				end
				if @schedulingEntries.new_record?
					@schedulingEntries.created_by_user_id = User.current.id
				end
				@schedulingEntries.updated_by_user_id = User.current.id
				@schedulingEntries.save
			else
				errorMsg = @schedulingEntries.errors.full_messages.join("<br>")
			end
		end
		if errorMsg.blank?
			flash[:notice] = l(:notice_successful_update)
		else
			flash[:error] = errorMsg 
		end
		redirect_to :controller => controller_name,:action => 'index' , :tab => 'wkscheduling'	
	end
	
	def createSchedulingObject(model, id)
		unless id.blank?
			@schedulingEntries = model.find(id.to_i)
		else
			@schedulingEntries = model.new
		end
	end
	
	def schedulingFilterValues		
		userIds = User.current.id
		set_filter_session
		departmentId =  session[controller_name].try(:[], :department_id)
		locationId =  session[controller_name].try(:[], :location_id)
		sqlStr = getLocationDeptSql
		if @schedulesShift || @editShiftSchedules
			if (!departmentId.blank? && departmentId.to_i != 0 ) && !locationId.blank?
				entries = WkUser.includes(:user).where(:department_id => departmentId.to_i, :location_id => locationId.to_i)
				@shiftRoles = WkShiftRole.where(:department_id => departmentId.to_i, :location_id => locationId.to_i)
				sqlStr = sqlStr + " where l.id = #{locationId.to_i} and d.id = #{departmentId.to_i}"
			elsif (!departmentId.blank? && departmentId.to_i != 0 ) && locationId.blank?
				entries = WkUser.includes(:user).where(:department_id => departmentId.to_i)
				@shiftRoles = WkShiftRole.where(:department_id => departmentId.to_i)
				sqlStr = sqlStr + " where d.id = #{departmentId.to_i}"
			elsif (departmentId.blank? || departmentId.to_i == 0 ) && !locationId.blank?
				entries = WkUser.includes(:user).where(:location_id => locationId.to_i)
				@shiftRoles = WkShiftRole.where(:location_id => locationId.to_i)
				sqlStr = sqlStr + " where l.id = #{locationId.to_i} "
			else
				entries = WkUser.includes(:user).all
				@shiftRoles = WkShiftRole.order(:location_id, :department_id)
			end
			sqlStr = sqlStr + " order by l.id"
			#@locationDept = @shiftRoles.pluck(:location_id, :department_id).uniq
			@locationDept = WkLocation.find_by_sql(sqlStr)
			if !params[:name].blank?
				entries = entries.where("users.type = 'User' and (LOWER(users.firstname) like LOWER('%#{params[:name]}%') or LOWER(users.lastname) like LOWER('%#{params[:name]}%'))")
			end
			userIds = entries.pluck(:user_id) 
			userIds = [0] if userIds.blank?
		end
		userIds
	end
	
	def set_filter_session
		if params[:searchlist] == controller_name
			session[controller_name] = Hash.new if session[controller_name].nil?
			filters = [:location_id, :department_id, :shift_id, :day_off]
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
