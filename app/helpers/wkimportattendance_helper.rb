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

module WkimportattendanceHelper	
	include WktimeHelper
	include WkattendanceHelper
	require 'csv' 
	#Copied from UserHelper
	
	def importAttendance(file,isAuto)
		lastAttnEntriesHash = Hash.new
		@errorHash = Hash.new
		@importCount = 0
		userCFHash = Hash.new
		custom_fields = UserCustomField.order('name')
		userIdCFHash = Hash.new
		unless custom_fields.blank?
			userCFHash = Hash[custom_fields.map { |cf| [cf.id, cf.name] }]
		end
		csv = read_file(file)
		lastAttnEntries = findLastAttnEntry(false)
		lastAttnEntries.each do |entry|
			lastAttnEntriesHash[entry.user_id] = entry
		end
		columnArr = Setting.plugin_redmine_wktime['wktime_fields_in_file']
		wkUserCFHash = getUserIdWkCFHash(get_wkuser_custom_ids)
		if !(csv.length > 0)
			@errorMsg = @errorMsg.blank? ? l('error_no_record_to_import') : @errorMsg.to_s + " <br/>" + l('error_no_record_to_import')
		end
		if columnArr.blank? || !(columnArr.length > 0)
			@errorMsg = @errorMsg.blank? ? l('warning_fields_in_file_not_configured') : @errorMsg.to_s + " <br/>" + l('warning_fields_in_file_not_configured')
		end
		if @errorMsg.blank?
	
			csv.each_with_index do |row,index|
				# rowValueHash - Have the data of the current row
				rowValueHash = Hash.new
				columnArr.each_with_index do |col,i|
					case col when "user_id"
						rowValueHash["user_id"] = row[i]			
					when "id1", "id2", "id3"
						#rowValueHash["cf_id1"] = row[i]
						if wkUserCFHash[col].blank? || wkUserCFHash[col][row[i]].blank?
							@errorHash[index+1] = row[i] + " " + l('activerecord.errors.messages.invalid')
						else
							rowValueHash["user_id"] = wkUserCFHash[col][row[i]]	
						end
					when "start_time","end_time"
						if row_date(row[i]).is_a?(DateTime) || (row[i].blank? && col == "end_time")
							rowValueHash[col] = row_date(row[i]) 
						else
							#isValid = false
							@errorHash[index+1] = col + " " + l('activerecord.errors.messages.invalid')
						end
					when "hours"
						rowValueHash[col] = row[i].to_f
					else
						if index < 1
							cfId = col.to_i #userCFHash[col] 
							userIdCFHash = getUserIdCFHash(cfId)
						end
						if userIdCFHash[row[i]].blank?
							@errorHash[index+1] = userCFHash[col.to_i] + " " + l('activerecord.errors.messages.invalid')
						else
							rowValueHash["user_id"] = userIdCFHash[row[i]]	
						end
					end
				end
				# Check the row has any invalid entries and skip that row from import
				if @errorHash[index+1].blank?
					@importCount = @importCount + 1
					userId = rowValueHash["user_id"] #row[0].to_i
					endEntry = nil
					startEntry = getFormatedTimeEntry(rowValueHash["start_time"])
					if !rowValueHash["end_time"].blank? && (rowValueHash["end_time"] != rowValueHash["start_time"]) 
						endEntry = getFormatedTimeEntry(rowValueHash["end_time"]) 
					end
					
					if (columnArr.include? "end_time") && (columnArr.include? "start_time")
						#Get the imported records for particular user and start_time
						importedEntry = WkAttendance.where(:user_id => userId, :start_time => startEntry)
						if  importedEntry[0].blank? 
							# There is no records for the given user on the given start_time
							# Insert a new record to the database
							lastAttnEntriesHash[userId] = addNewAttendance(startEntry,endEntry,userId)
						else
							# Update the record with end Entry
							if importedEntry[0].end_time.blank? && !endEntry.blank?
								lastAttnEntriesHash[userId] = saveAttendance(importedEntry[0], startEntry, endEntry, userId, true)
							end
						end
					else
						# Get the imported records for particular user and entry_time
						# Skip the records which is already inserted by check importedEntry[0].blank? 
						importedEntry = WkAttendance.where("user_id = ? AND (start_time = ? OR end_time = ?)", userId, startEntry, startEntry)
						if importedEntry[0].blank? 
							lastAttnEntriesHash[userId] = saveAttendance(lastAttnEntriesHash[userId], startEntry, endEntry, userId, false)	
						end
					end
				end
			end
			Rails.logger.info("==== #{l(:notice_import_finished, :count => @importCount)} ====")
			Rails.logger.info("==== #{l(:notice_import_finished_with_errors, :count => @errorHash.count, :total => (@errorHash.count + @importCount))} ====")
			if isAuto
				Rails.logger.info("====== File Name = #{File.basename file}=========")
				if  @importCount > 0
					Rails.logger.info("==== #{l(:notice_import_finished, :count => @importCount)} ====")
				end
				if !@errorHash.blank? && @errorHash.count > 0
					Rails.logger.info("==== #{l(:notice_import_finished_with_errors, :count => @errorHash.count, :total => (@errorHash.count + @importCount))} ====")
					Rails.logger.info("===============================================================")
					Rails.logger.info("       Row           ||        Message            ")
					Rails.logger.info("===============================================================")
					@errorHash.each do |item|
						Rails.logger.info("    #{item[0]}           || #{simple_format_without_paragraph item[1]}")
						Rails.logger.info("---------------------------------------------------------------")
					end
					Rails.logger.info("===============================================================")
				end
			end
			return @errorHash.blank? || @errorHash.count < 0
		else
			return false
		end
	end
	
	def read_file(file)
		csv_text = File.read(file)
		hasHeaders = (Setting.plugin_redmine_wktime['wktime_import_file_headers'].blank? || Setting.plugin_redmine_wktime['wktime_import_file_headers'].to_i == 0) ? false : true
		csv_options = {:headers => hasHeaders}
		csv_options[:encoding] = Setting.plugin_redmine_wktime['wktime_field_encoding']#'UTF-8'
		separator = Setting.plugin_redmine_wktime['wktime_field_separator']#','
		csv_options[:col_sep] = separator if separator.size == 1
		wrapper = Setting.plugin_redmine_wktime['wktime_field_wrapper']#'"'
		csv_options[:quote_char] = wrapper if wrapper.size == 1
		csv = CSV.parse(csv_text, csv_options)
		csv
	end
	
	# def getFormatedTimeEntry(entryDateTime)
		# entryTime = nil
		# if !entryDateTime.blank?
			# entryLocal = entryDateTime.change(:offset => Time.current.localtime.strftime("%:z"))
			# entryTime = Time.parse("#{entryLocal.to_date.to_s} #{entryLocal.utc.to_time.to_s} ").localtime
		# end
		# entryTime
	# end
	
	def getUserIdCFHash(cfId)
		cfValHash = Hash.new
		cfValue = CustomValue.where("custom_field_id = #{cfId}")
		unless cfValue.blank?
			#cfs = custom_fields.collect {|cf| userCFHash[cf.name] = cf.id }
			cfValHash = Hash[cfValue.map { |cfv| [cfv.value, cfv.customized_id] }]
		end
		cfValHash
	end
	
	def getUserIdWkCFHash(fieldNameArr)
		fieldWkUserHash = Hash.new
		wkUsers = WkUser.all
		unless wkUsers.blank?
			wkUsers.each do |wkusr|
				fieldNameArr.each do |field|				
					fieldWkUserHash[field] = fieldWkUserHash[field].blank? ? {wkusr[field] => wkusr.user_id} : fieldWkUserHash[field].merge({wkusr[field] => wkusr.user_id})
				end
			end
		end
		fieldWkUserHash
	end
	
	def row_date(dateTimeStr)
			format = Setting.plugin_redmine_wktime['wktime_field_datetime']#"%Y-%m-%d %T"
			DateTime.strptime(dateTimeStr, format) rescue dateTimeStr
	end
	
	def calcSchdulerInterval
		interval = (Setting.plugin_redmine_wktime['wktime_auto_import_time_hr'].to_i*60) + (Setting.plugin_redmine_wktime['wktime_auto_import_time_min'].to_i)
		intervalMin = interval>0 ? interval.to_s + 'm' : '60m'
		intervalMin
	end
	
	def get_wkuser_custom_ids
		["id1", "id2", "id3"]
	end

end
