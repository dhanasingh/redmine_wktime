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

class RoundRobinSchedule
	
	# Schedule for the give location and department
	# Target shift - the shift which we are going to schedule
	# Source Shift - The shift which we take the users from (Previous shift)
	def schedule(locationId, deptId, from, to)
		destroySchedules(locationId, deptId, from, to)
		roleUserHash = getRoleWiseUser(locationId, deptId, from, to)
		currentRoleUserHash = roleUserHash.deep_dup #getRoleWiseUser(locationId, deptId)
		lastShiftHash = getLastShiftDetails(locationId, deptId, from, to, 'W')
		lastDayOffHash = getLastShiftDetails(locationId, deptId, from, to, 'D')
		periodDays = getDaysBetween(from, to)
		reqStaffHash = getRequiredStaffHash(locationId, deptId, currentRoleUserHash, periodDays)
		minStaffMoveHash = getMinStaffMove(reqStaffHash)
		shifts = WkShift.where(:id => reqStaffHash.keys).order(start_time: :desc).pluck(:id)
		totalShifts = shifts.length
		allocatedHash = Hash.new
		scheduledUserIds = Array.new
		unScheduledLstSftUsr = lastShiftHash
		shifts.each_with_index do |shift, index|
			reqStaffHash[shift].each do |role, staff|
				if currentRoleUserHash[role].blank? || staff < 1
					next
				end
				
				sourceShift = getSourceShift(reqStaffHash, shift, shifts, role)
				#sourceShift = shifts[(index+1)%totalShifts]
				if unScheduledLstSftUsr[sourceShift].blank? || unScheduledLstSftUsr[sourceShift][role].values[0].blank?
					availableUsers = currentRoleUserHash[role].keys
					pickedUserIds = availableUsers[ 0 .. staff -1 ]
				else
					availableUsers = currentRoleUserHash[role].keys
					pickedUserIds = Array.new 
					sourceShiftLastUsrs = unScheduledLstSftUsr[sourceShift][role].select { |uid, schDt| !schDt.blank? && schDt > getPrevPeriodStart(from)}
					targetShiftLastUsrs = unScheduledLstSftUsr[shift][role].select { |uid, schDt| schDt.blank? || schDt > getPrevPeriodStart(from)}
					
					# Sort the users Ascending order by last working date on the target shift
					# Pick the least recently working staff on the target shift from source shift until reach the minimum staff move count
					# Those who are not Woking a single day on sourceShift will have last working day as blank
					# First allocate the users those who are working on sourceShift last week
					targetShftLastUsersAsc = unScheduledLstSftUsr[shift][role].sort_by { |uid, schDt| schDt || Date.new(1900) }
					sourceShftLastUsersDesc = unScheduledLstSftUsr[sourceShift][role].sort_by { |uid, schDt| schDt || Date.new(1900) }.reverse
					targetShftLastUsersAsc.each do |id, schDt|
						pickedUserIds << id if sourceShiftLastUsrs.has_key?(id) && currentRoleUserHash[role].has_key?(id) && !sourceShiftLastUsrs[id].blank? && !(pickedUserIds.include? id)
						break if pickedUserIds.length == minStaffMoveHash[role]
					end
					
					# if not matched number of users worked on the last week then pick the users from the last week staff on source shift
					# Pick the least recently working staff on the target shift from source shift
					# Allocate the sourceShift staff who are not working in target shift 
					unless pickedUserIds.length == minStaffMoveHash[role]
						sourceShiftLastUsrs.each do |userId, schdt|
							pickedUserIds << userId if currentRoleUserHash[role].has_key?(userId) && !(pickedUserIds.include? userId)
							break if pickedUserIds.length == minStaffMoveHash[role]
						end
					end
					targetShiftLastUsrs.except!(*pickedUserIds)
					
					# After the minimum staff move then keep some staff from the same shift(Target shift)
					# additionalCount = staff-pickedUserIds.length
					# Keep the users those who are working recently on Source shift
					if (staff - pickedUserIds.length) > 0
						sourceShftLastUsersDesc.each do |userId, schdt|
							pickedUserIds << userId if currentRoleUserHash[role].has_key?(userId) && !(pickedUserIds.include? userId) && targetShiftLastUsrs.has_key?(userId)
							break if pickedUserIds.length == staff
						end
					end
					
					# Finally pick the remaining required staff from currentRoleUserHash
					# additionalCount = staff-pickedUserIds.length
					if (staff - pickedUserIds.length) > 0
						currentRoleUserHash[role].each do |userId, userObj|
							pickedUserIds << userId if !(pickedUserIds.include? userId)
							break if pickedUserIds.length == staff
						end
					end
					
				end
				pickedUsersHash = currentRoleUserHash[role].select {|k,v| pickedUserIds.include? k }
				scheduledUserIds = scheduledUserIds + pickedUserIds
				if allocatedHash[shift].blank?
					allocatedHash[shift] = { role => pickedUsersHash.keys} 
				else
					allocatedHash[shift].store(role, pickedUsersHash.keys)
				end
				currentRoleUserHash[role].except!( *pickedUserIds )
			end
		end
		if scheduleByPreference
			userpreference = getUserPreference(locationId, deptId, from, to)
			allocatedHash = applyPreference(userpreference, allocatedHash, roleUserHash)
		end
		holidays = getHolidays(locationId, from, to)
		saveSchedules(allocatedHash, from, to, lastDayOffHash, holidays, locationId, deptId)
	end
	
	# Return Shift id where staff has to be taken for the target shift
	def getSourceShift(reqStaffHash, targetShiftId, sortedShiftArr, roleId)
		curRoleShifts = Array.new
		sortedShiftArr.each do |shiftId|
			if !reqStaffHash[shiftId].blank? && (!reqStaffHash[shiftId][roleId].blank? && reqStaffHash[shiftId][roleId] > 0)
				curRoleShifts << shiftId
			end
		end
		targetShiftIndex = curRoleShifts.index(targetShiftId) 
		curRoleTotalShifts = curRoleShifts.length
		sourceShift = curRoleShifts[(targetShiftIndex+1)%curRoleTotalShifts]
		sourceShift
	end
	
	# return array of holiday dates for the give location and period
	def getHolidays(locationId, from, to)
		holidays = Array.new
		unless isScheduleOnWeekEnd
			holidays = WkPublicHoliday.where(:location_id => locationId, :holiday_date => from .. to).pluck(:holiday_date)
		end
		holidays
	end
	
	# Return start of the previous period
	# Current code only for week. 
	def getPrevPeriodStart(currentStart)
		prevStart = nil
		if getIntervalType == 'M'
			prevStart = currentStart - 1.months
		else
			prevStart = currentStart - 7.days
		end
		prevStart
	end
	
	# Allocate the staff preferred shift at maximum possibility
	def applyPreference(preference, rrAllocation, roleUserHash)
		currentRoleUserHash = roleUserHash
		# Add the users those who don't have shift preference to the shift preference on RR allocated shift
		currentPreference = reArrangePreference(preference, rrAllocation)
		
		# Preference Algorithm
		currentAllocation = Hash.new
		currentAllocation = rrAllocation.deep_dup
		preferedAllocation = Hash.new
		currentAllocation.each do |shiftId, pickedRolehash|
			pickedRolehash.each do |role, allocatedUsers|
				pickedUsers = Array.new
				unless currentPreference[shiftId].blank? || currentPreference[shiftId][role].blank?
				
					preferredUsers = currentPreference[shiftId][role]
					
					# 1. preferred staff less than required staff on any shift
					# Allocate all staff to that shift those who were preferred that shift
					# 2. preferred staff greater than required staff on any shift
					# First allocate the RR scheduled staff to that shift those who preferred the same shift
					
					if preferredUsers.length <= allocatedUsers.length
						pickedUsers = preferredUsers
					else
						pickedUsers = preferredUsers & allocatedUsers
					end
				end
					
				if preferedAllocation[shiftId].blank?
					preferedAllocation[shiftId] = { role => pickedUsers} 
				else
					preferedAllocation[shiftId].store(role, pickedUsers)
				end
				
				if !preferedAllocation[shiftId].blank? && !preferedAllocation[shiftId][role].blank? && !pickedUsers.empty?
					currentAllocation[shiftId][role] = currentAllocation[shiftId][role] - preferedAllocation[shiftId][role]
					currentPreference[shiftId][role] = currentPreference[shiftId][role] - preferedAllocation[shiftId][role]
				end
				currentRoleUserHash[role].except!( *pickedUsers ) 
			end
		end
		
		# 1. Take the staff from their preference for the remaining vacancies
		currentAllocation.each do |shiftId, pickedRolehash|
			pickedRolehash.each do |role, allocatedUsers|
				pickedCount = preferedAllocation[shiftId][role].length
				requiredCount = rrAllocation[shiftId][role].length
				pickedUsers = Array.new
				unless currentPreference[shiftId].blank? || currentPreference[shiftId][role].blank?
					preferredUsers = currentPreference[shiftId][role]
					unless pickedCount == requiredCount
						pickedUsers = preferredUsers.first(requiredCount - pickedCount)
						preferedAllocation[shiftId][role] = preferedAllocation[shiftId][role] + pickedUsers
					end
				end
				if !preferedAllocation[shiftId].blank? && !preferedAllocation[shiftId][role].blank? && !pickedUsers.empty?
					currentAllocation[shiftId][role] = currentAllocation[shiftId][role] - preferedAllocation[shiftId][role]
					currentPreference[shiftId][role] = currentPreference[shiftId][role] - preferedAllocation[shiftId][role]
				end
				currentRoleUserHash[role].except!( *pickedUsers )
			end
		end
		
		# 1. Take the staff from the actual allocation for the remaining vacancies
		currentAllocation.each do |shiftId, pickedRolehash|
			pickedRolehash.each do |role, allocatedUsers|
				pickedCount = preferedAllocation[shiftId][role].length
				requiredCount = rrAllocation[shiftId][role].length
				pickedUsers = Array.new
				unless pickedCount == requiredCount
					availableUsers = allocatedUsers & currentRoleUserHash[role].keys
					pickedUsers = availableUsers.first(requiredCount - pickedCount)
					preferedAllocation[shiftId][role] = preferedAllocation[shiftId][role] + pickedUsers
				end
				if !preferedAllocation[shiftId].blank? && !preferedAllocation[shiftId][role].blank?
					currentAllocation[shiftId][role] = currentAllocation[shiftId][role] - preferedAllocation[shiftId][role]
					unless currentPreference[shiftId].blank? || currentPreference[shiftId][role].blank?
						currentPreference[shiftId][role] = currentPreference[shiftId][role] - preferedAllocation[shiftId][role]
					else
						if currentPreference[shiftId].blank?
							currentPreference[shiftId] = { role => []} 
						else
							currentPreference[shiftId].store(role, [])
						end
					end
				end
				currentRoleUserHash[role].except!( *pickedUsers )
			end
		end
		
		# Fill the remaining vacancies from the available staff
		currentAllocation.each do |shiftId, pickedRolehash|
			pickedRolehash.each do |role, allocatedUsers|
				pickedCount = preferedAllocation[shiftId][role].length
				requiredCount = rrAllocation[shiftId][role].length
				pickedUsers = Array.new
				unless pickedCount == requiredCount
					pickedUsers = currentRoleUserHash[role].keys.first(requiredCount - pickedCount)
					preferedAllocation[shiftId][role] = preferedAllocation[shiftId][role] + pickedUsers
				end
				if !preferedAllocation[shiftId].blank? && !preferedAllocation[shiftId][role].blank?
					currentAllocation[shiftId][role] = currentAllocation[shiftId][role] - preferedAllocation[shiftId][role]
					#currentPreference[shiftId][role] = currentPreference[shiftId][role] - preferedAllocation[shiftId][role]
					unless currentPreference[shiftId].blank? || currentPreference[shiftId][role].blank?
						currentPreference[shiftId][role] = currentPreference[shiftId][role] - preferedAllocation[shiftId][role]
					else
						if currentPreference[shiftId].blank?
							currentPreference[shiftId] = { role => []} 
						else
							currentPreference[shiftId].store(role, [])
						end
					end
				end
				currentRoleUserHash[role].except!( *pickedUsers )
			end
		end
		preferedAllocation
	end
	
	# Allocate RR allocated shift as preference for the staff those who don't have preference
	def reArrangePreference(userPreference, rrAllocation)
		unless userPreference[0].blank?
			rrAllocation.each do |shiftId, pickedRolehash|
				pickedRolehash.each do |role, allocatedUsers|
					unless userPreference[0][role].blank?
						unPreferedUsers = userPreference[0][role]
						curSftUnPreferedUsers = allocatedUsers & unPreferedUsers
						if userPreference[shiftId].blank? #|| userPreference[shiftId][role].blank?
							userPreference[shiftId] = { role => curSftUnPreferedUsers} 
						else
							unless userPreference[shiftId][role].blank?
								userPreference[shiftId][role] = userPreference[shiftId][role] + curSftUnPreferedUsers
							else
								userPreference[shiftId][role] = curSftUnPreferedUsers
							end
						end
					end					
				end
			end
		end
		userPreference
	end
	
	# Return the user preference from schedule priorities
	def getUserPreference(locationId, deptId, from, to)
		sqlStr =  "select u.id as user_id, wu.location_id, wu.department_id, wu.termination_date, wu.join_date," +
		" wu.role_id, wu.is_schedulable, sp.schedule_date, sp.schedule_type, sp.schedule_as, sp.shift_id from users u inner join wk_users wu on u.id = wu.user_id left outer join wk_shift_schedules sp on (u.id = sp.user_id and sp.schedule_type = 'P' and sp.schedule_date = '#{from}')"
		sqlCond = " where (wu.termination_date IS NULL OR wu.termination_date >= '#{to}') and wu.is_schedulable = #{true} AND wu.join_date <= '#{from}'" # and wu.is_schedulable = #{true}
		unless deptId.blank?
			sqlCond = sqlCond + " and department_id = #{deptId}"
		end
		unless locationId.blank?
			sqlCond = sqlCond + " and location_id = #{locationId}"
		end
		sqlStr = sqlStr + sqlCond
		preferenceHash = Hash.new
		userPreference = User.find_by_sql(sqlStr)
		userPreference.each do |entry|
			shiftId = entry.shift_id.blank? ? 0 : entry.shift_id
			if preferenceHash[shiftId].blank?
				preferenceHash[shiftId] = { entry.role_id => [entry.user_id]} 
			else
				existingUsers = preferenceHash[shiftId][entry.role_id]
				pickedUsers = Array.wrap(existingUsers) + [entry.user_id]
				preferenceHash[shiftId].store(entry.role_id, pickedUsers)
			end
		end
		preferenceHash
	end
	
	def scheduleByPreference
		(!Setting.plugin_redmine_wktime['wk_user_schedule_preference'].blank? && Setting.plugin_redmine_wktime['wk_user_schedule_preference'].to_i == 1)
	end
	
	# Return active users role wise
	# roleUserHash key as roll_id , value as userHash ( userId as key userObj as value)
	def getRoleWiseUser(locationId, deptId, from, to)
		#users = User.includes(:wk_user).where(:wk_users => {:location_id => locationId, :department_id => deptId, :termination_date => nil})
		users = User.includes(:wk_user).where("wk_users.location_id = ? AND wk_users.department_id = ? AND (wk_users.termination_date IS NULL OR wk_users.termination_date >= ?) AND wk_users.join_date <= ? and wk_users.is_schedulable = ?", locationId, deptId, to, from, true).references(:wk_users)
		roleUserHash = Hash.new
		users.each do |entry|
			if roleUserHash[entry.wk_user.role_id].blank?
				roleUserHash[entry.wk_user.role_id] = { entry.id => entry}
			else
				roleUserHash[entry.wk_user.role_id].store(entry.id, entry)
			end
		end
		roleUserHash
	end
	
	# Return the required number of staff for each shift on each role
	# Required number of staff for given location and department
	# Here we have to check number of staff and and required staff are equal 
	# If not equal then we have to assign the staff as requested staff percentage in each shift
	def getRequiredStaffHash(locationId, deptId, roleUserHash, interval)
		schedulableShifts = WkShift.where(:is_schedulable => true, :in_active => true).pluck(:id)
		allLDShiftRoles = WkShiftRole.where(:location_id => nil, :department_id => nil, :shift_id => schedulableShifts)
		locationShiftRoles = WkShiftRole.where(:location_id => locationId, :department_id => nil, :shift_id => schedulableShifts )
		deptShiftRoles = WkShiftRole.where(:location_id => nil, :department_id => deptId, :shift_id => schedulableShifts)
		if deptId.blank?
			shiftRoles = WkShiftRole.where(:location_id => locationId, :shift_id => schedulableShifts)
		else
			shiftRoles = WkShiftRole.where(:location_id => locationId, :department_id => deptId, :shift_id => schedulableShifts)
		end
		reqStaffHash = Hash.new
		
		# Collect the all the Location and department required staff
		allLDShiftRoles.each do |entry|
			if reqStaffHash[entry.shift_id].blank?
				reqStaffHash[entry.shift_id] = { entry.role_id => getReqStaffWithDayOff(entry.staff_count, interval)}
			else
				reqStaffHash[entry.shift_id].store(entry.role_id, getReqStaffWithDayOff(entry.staff_count, interval))
			end
		end
		
		# Over ride required staff count the for the given location
		locationShiftRoles.each do |entry|
			if reqStaffHash[entry.shift_id].blank?
				reqStaffHash[entry.shift_id] = { entry.role_id => getReqStaffWithDayOff(entry.staff_count, interval)}
			else
				reqStaffHash[entry.shift_id].store(entry.role_id, getReqStaffWithDayOff(entry.staff_count, interval))
			end
		end
		
		# Over ride required staff count the for the given Department
		deptShiftRoles.each do |entry|
			if reqStaffHash[entry.shift_id].blank?
				reqStaffHash[entry.shift_id] = { entry.role_id => getReqStaffWithDayOff(entry.staff_count, interval)}
			else
				reqStaffHash[entry.shift_id].store(entry.role_id, getReqStaffWithDayOff(entry.staff_count, interval))
			end
		end
		
		# Over ride required staff count the for the given Department and location
		shiftRoles.each do |entry|
			if reqStaffHash[entry.shift_id].blank?
				reqStaffHash[entry.shift_id] = { entry.role_id => getReqStaffWithDayOff(entry.staff_count, interval)}
			else
				reqStaffHash[entry.shift_id].store(entry.role_id, getReqStaffWithDayOff(entry.staff_count, interval))
			end
		end
		# Scenario for required staff less or high 
		roleStaffCount = Hash.new
		
		roleUserHash.each do | role, users|
			roleStaffCount[role] = users.length
		end
		remainingStaff = roleStaffCount.deep_dup
		
		totReqStaffHash = Hash.new
		reqStaffHash.each do | shift, role|
			role.each do | roleId, count|
				if totReqStaffHash[roleId].blank?
					totReqStaffHash[roleId] = count
				else
					totReqStaffHash[roleId] = totReqStaffHash[roleId] + count
				end
				
			end
		end
		alteredReqStaff = Hash.new
		roundOffHash = Hash.new
		reqStaffHash.each do | shift, roleHash|
			roleHash.each do | roleId, actualStaffCount|
				if !remainingStaff[roleId].blank? && remainingStaff[roleId] > 0 && actualStaffCount > 0
					alteredStaffCount = (actualStaffCount.to_f / totReqStaffHash[roleId].to_f) * roleStaffCount[roleId].to_f
					staffCount = alteredStaffCount.round #> remainingStaff[roleId] ?  remainingStaff[roleId] : alteredStaffCount.round
					lastRoundBal = roundOffHash[roleId].blank? ? 0 : roundOffHash[roleId]
					curRoundOff = alteredStaffCount - staffCount
					totalRoundOff = lastRoundBal + curRoundOff
					unless totalRoundOff.round(2) < 1.0 && totalRoundOff.round(2) > -1.0
						additionalStaff = totalRoundOff.round
						staffCount = staffCount + additionalStaff
						totalRoundOff = (totalRoundOff - additionalStaff).round(2)
					end
					
					if alteredReqStaff[shift].blank?
						alteredReqStaff[shift] = {roleId => staffCount}
					else
						alteredReqStaff[shift][roleId] = staffCount
					end
					roundOffHash[roleId] = totalRoundOff
					remainingStaff[roleId] = remainingStaff[roleId] - staffCount
					
				end
			end
		end
		alteredReqStaff
	end
	
	# Return required number of staff with inclusive of day off 
	def getReqStaffWithDayOff(actualRequiremnt, interval)
		dayOffCount = getDayOffCount
		requiredStaff = actualRequiremnt
		if isScheduleOnWeekEnd
			requiredStaff = ((actualRequiremnt*interval).to_f/(interval-dayOffCount).to_f).ceil
		end
		requiredStaff
	end
	
	# return number of days between two dates
	def getDaysBetween(from, to)
		(to.to_date - from.to_date).to_i + 1
	end
	
	# Save the scheduled hash entries
	def saveSchedules(allocatedHash, from, to, lastDayOffHash, holidays, locationId, deptId)
		currentUserId = User.current.blank? ? nil : User.current.id
		allocatedHash.each do |shiftId, pickedRolehash|
			pickedRolehash.each do |roleId, pickedUsers|
				dayOffs = getDayOffs(pickedUsers, from, to, lastDayOffHash)
				pickedUsers.each do |userId|
					from.upto(to) do |shiftDate|
						schedule = WkShiftSchedule.where(:schedule_date => shiftDate, :user_id => userId, :schedule_type => 'S').first_or_initialize(:schedule_date => shiftDate, :user_id => userId, :schedule_type => 'S')
						if holidays.include? shiftDate
							schedule.schedule_as = 'H'
						elsif !dayOffs[userId].blank? && (dayOffs[userId].include? shiftDate)#dayOffs[userId].include? shiftDate
							schedule.schedule_as = 'O'
						else
							schedule.schedule_as = 'W'
						end
						schedule.created_by_user_id = currentUserId if schedule.new_record?
						schedule.updated_by_user_id = currentUserId
						schedule.shift_id = shiftId
						schedule.save
					end
				end
			end
		end
	end
	
	# Destroy schedules for the given interval , location and department
	def destroySchedules(locationId, deptId, from, to)
		userIds = WkUser.where(:location_id => locationId, :department_id => deptId).pluck(:user_id)
		WkShiftSchedule.where(:schedule_date => from .. to, :user_id => userIds, :schedule_type => 'S').destroy_all
	end
	
	# return the day Off schedules for the users
	def getDayOffs(userIdsArr, from, to, lastDayOff)
		dayOffCount = getDayOffCount
		dayOffHash = Hash.new
		# period = "W"
		# isConsecutive = true
		# userLastDayOff = lastDayOff.select { |userId, dayOff| userIdsArr.include? userId }
		# sortedUserLastDayOff = lastDayOff.sort_by { |uid, schDt| schDt || Date.new(1900) }
		noOfUsers = userIdsArr.length
		noOfDays = getDaysBetween(from, to)#(to - from).to_i + 1 
		minWorkersPerDay = (noOfUsers * (noOfDays - dayOffCount)) / noOfDays
		# minLeaveUsrPerDay = (noOfUsers * dayOffCount) / 7
		# maxLeaveUsrPerDay = minLeaveUsrPerDay + 1
		maxLeaveUsrPerDay = noOfUsers - minWorkersPerDay
		# noOfDaysHasMaxLeave = (noOfUsers * dayOffCount) % 7
		# nextDate = from
		# interval = 1
		# scheduleOnWeekEnds = false
		# if Setting.plugin_redmine_wktime['wk_schedule_on_weekend'].to_i == 1
			# scheduleOnWeekEnds = true
		# end
		weekEndArr = getWeekEndArr(from) 
		dofUserAllocateHash = Hash.new
		remaingDOHash = Hash.new
		if scheduleByPreference && isScheduleOnWeekEnd && dayOffCount>0
			userPreference = getUserPreferenceDO(userIdsArr, from, to)
			
			# Allocate the prefered users dayoffs 
			from.upto(to) do |offDt|
				userIds = userPreference[offDt]
				unless userIds.blank?
					userIds.each do|userId|
						if dayOffHash[userId].blank? || dayOffHash[userId].length < dayOffCount
							dofUserAllocateHash[offDt] = dofUserAllocateHash[offDt].blank? ? [userId] : dofUserAllocateHash[offDt] + [offDt]
							dayOffHash[userId] = dayOffHash[userId].blank? ? [offDt] : dayOffHash[userId] + [offDt]
						end
						break if !dofUserAllocateHash[offDt].blank? && dofUserAllocateHash[offDt].length == maxLeaveUsrPerDay
					end
					allocatedDayOff = dofUserAllocateHash[offDt].blank? ? 0 : dofUserAllocateHash[offDt].length
					remaingDOHash[offDt] = maxLeaveUsrPerDay - allocatedDayOff
				else
					remaingDOHash[offDt] = maxLeaveUsrPerDay
				end
			end
			
			# Allocate Dayoffs for those who are dont have any preference
			userIdsArr.each_with_index do |userId, index|
				if dayOffHash[userId].blank? || dayOffHash[userId].length < dayOffCount
					from.upto(to) do |offDt|
						if dofUserAllocateHash[offDt].blank? || dofUserAllocateHash[offDt].length < maxLeaveUsrPerDay
							dofUserAllocateHash[offDt] = dofUserAllocateHash[offDt].blank? ? [userId] : dofUserAllocateHash[offDt] + [offDt]
							dayOffHash[userId] = dayOffHash[userId].blank? ? [offDt] : dayOffHash[userId] + [offDt]
						end
						break if !dayOffHash[userId].blank? && dayOffHash[userId].length == dayOffCount
					end
				end
			end
			
			# This Section need to modify. 
			# Scenerio: 'Staff A' has 2 days leave but there is one day only available with maxLeaveUsrPerDay
			# So you cound not assign 2 days to that user.
			# Currently we have assign some other day as leave to 'Staff A'
			# It leads to lack required staff on that day
			# You need to rearrange the dayOffs to solve this 
			unscheduleUserCnt = 0
			userIdsArr.each_with_index do |userId, index|
				if dayOffHash[userId].blank? || dayOffHash[userId].length < dayOffCount
					givenOff = dayOffHash[userId].blank? ? 0 : dayOffHash[userId].length
					for dof in 0..dayOffCount-1-givenOff
						offDt = from + (((unscheduleUserCnt * dayOffCount) + dof) % noOfDays).days
						unless givenOff == 0
							until !dayOffHash[userId].include? offDt
								unscheduleUserCnt = unscheduleUserCnt + 1
								offDt = from + (((unscheduleUserCnt * dayOffCount) + dof) % noOfDays).days
							end
						end 
						dofUserAllocateHash[offDt] = dofUserAllocateHash[offDt].blank? ? [userId] : dofUserAllocateHash[offDt] + [offDt]
						dayOffHash[userId] = dayOffHash[userId].blank? ? [offDt] : dayOffHash[userId] + [offDt]
					end
					unscheduleUserCnt = unscheduleUserCnt + 1
				end
			end
		else
			userIdsArr.each_with_index do |userId, index|
				dayOffArr = Array.new
				#firstLeaveDt = from + ((index * dayOffCount) % noOfDays).days
				if isScheduleOnWeekEnd
					for dof in 0..dayOffCount-1
						# This calculation will give the next day of last given dayoff
						dayOffArr << from + (((index * dayOffCount) + dof) % noOfDays).days
					end
				else
					dayOffArr = weekEndArr
				end
				dayOffHash[userId] = dayOffArr
			end
		end
		dayOffHash
	end
	
	# Return weekend dates as array for the given week start
	def getWeekEndArr(weekStartDt)
		weekEndArr = Array.new
		weekArr = Setting.plugin_redmine_wktime['wk_schedule_weekend'].to_a
		unless weekArr.blank?
			weekArr.each do | day |
				weekEndArr << getDayOnWeek(weekStartDt, day.to_i)
			end
		end
		weekEndArr
	end
	
	# Return the next date value of the given day value
	# the day value of calendar week (0-6, Sunday is 0)	
	def getDayOnWeek(weekStart, dayVal)
		weekDay = ((7 + (dayVal - weekStart.wday)) % 7)
		dayDateVal = weekStart + weekDay.days
		dayDateVal
	end
	
	def isScheduleOnWeekEnd
		scheduleOnWeekEnds = false
		if Setting.plugin_redmine_wktime['wk_schedule_on_weekend'].to_i == 1
			scheduleOnWeekEnds = true
		end
		scheduleOnWeekEnds
	end
	
	# Return day off count per period
	def getDayOffCount
		dayCount = 0
		unless Setting.plugin_redmine_wktime['wk_schedule_weekend'].blank?
			dayCount = Setting.plugin_redmine_wktime['wk_schedule_weekend'].length
		end
		dayCount
	end
	
	# Return last working week shift schedule details
	def getLastShiftDetails(locationId, deptId, from, to, scheduleAs)
		lastShiftHash = nil
		selectShift = ""
		orderShift = ""
		joinCond = ""
		shift = ""
		joinShiftStr = ""
		if scheduleAs == 'W'
			selectShift = "s.id as shift_id,"
			orderShift = "s.id,"
			joinCond = "and ls.shift_id = s.id"
			shift = ", shift_id"
			joinShiftStr = " inner join wk_shifts s on (1=1)"
		end
		sqlStr = "SELECT wu.user_id, #{selectShift} ls.last_schedule_date, wu.location_id, wu.department_id," + 
			" wu.role_id from users u" + 
			" inner join wk_users wu on (wu.user_id = u.id and wu.is_schedulable = #{true} and (wu.termination_date IS NULL OR wu.termination_date >= '#{to}') AND wu.join_date <= '#{from}')" +
			joinShiftStr +
			" left join" +
			" (select user_id #{shift}, max(schedule_date) as last_schedule_date from wk_shift_schedules where schedule_as = '#{scheduleAs}' and schedule_date < '#{from}' and schedule_type = 'S' group by user_id #{shift}) ls on (ls.user_id = u.id #{joinCond})" 
		
		unless locationId.blank? || deptId.blank?
			sqlStr = sqlStr + " where wu.location_id = #{locationId} AND wu.department_id = #{deptId}"
		else
			sqlStr = sqlStr + " where wu.location_id = #{locationId}" unless locationId.blank?
			sqlStr = sqlStr + " where wu.department_id = #{deptId}" unless deptId.blank?
		end
		sqlStr = sqlStr + " order by  #{orderShift} ls.last_schedule_date, u.id"
		lastShiftEntries = WkShiftSchedule.find_by_sql(sqlStr)
		if scheduleAs == 'W'
			lastShiftHash = getLastShiftHash(lastShiftEntries)
		else
			lastShiftHash = getLastDayOffHash(lastShiftEntries)
		end
		lastShiftHash
	end
	
	def getLastShiftHash(lastShiftEntries)
		lastShiftHash = Hash.new
		lastShiftEntries.each do |entry|
			if lastShiftHash[entry.shift_id].blank?
				lastShiftHash[entry.shift_id] = { entry.role_id => {entry.user_id => entry.last_schedule_date}} 
			else
				if lastShiftHash[entry.shift_id][entry.role_id].blank?
					lastShiftHash[entry.shift_id][entry.role_id] = {entry.user_id => entry.last_schedule_date}
				else
					lastShiftHash[entry.shift_id][entry.role_id].store(entry.user_id, entry.last_schedule_date)
				end
			end
		end
		lastShiftHash
	end
	
	def getLastDayOffHash(lastShiftEntries)
		lastDayOffHash = Hash.new
		lastShiftEntries.each do |entry|
			lastDayOffHash[entry.user_id] = entry.last_schedule_date
		end
		lastDayOffHash
	end
	
	def getMinStaffMove(reqStaffHash)
		minStaffMoveHash = Hash.new
		reqStaffHash.each do |shift, roleStaff|
			roleStaff.each do |role, staff|
				minStaffMoveHash[role] = staff if (minStaffMoveHash[role].blank? || minStaffMoveHash[role] > staff) && staff > 0
			end
		end
		minStaffMoveHash
	end
	
	# Return the interval value for the interval
	def getIntervalValue(intervalType)
		intervalVal = 1
		if intervalType == 'W'
			intervalVal = 7
		end
		intervalVal
	end
	
	# Return the interval type ie, Month, week etc
	def getIntervalType
		# get the interval type from settings
		# currently not implemented. It will useful in future
		intervalType = 'W'
		intervalType
	end
	
	# Return the each given users prefered dayoffs
	# dayOffUserPrefHash key - DayOff date Value - preffered users ids Array
	def getUserPreferenceDO(userIdsArr, from, to)
		userPreferenceDO = WkShiftSchedule.where(:schedule_type => 'P', :schedule_as => 'O', :user_id => userIdsArr, :schedule_date => from .. to).order(:updated_at)
		dayOffUserPrefHash = Hash.new
		userPreferenceDO.each do |entry|
			dayOffUserPrefHash[entry.schedule_date] = dayOffUserPrefHash[entry.schedule_date].blank? ? [entry.user_id] : (dayOffUserPrefHash[entry.schedule_date] + [entry.user_id])
		end
		dayOffUserPrefHash
	end
end
