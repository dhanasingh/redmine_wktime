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
		currentRoleUserHash = getRoleWiseUser(locationId, deptId)
		lastShiftHash  = getLastShiftDetails(locationId, deptId, from, to, 'W')
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
				if currentRoleUserHash[role].blank?
					next
				end
				sourceShift = shifts[(index+1)%totalShifts]
				if unScheduledLstSftUsr[sourceShift].blank? || unScheduledLstSftUsr[sourceShift][role].values[0].blank?
					availableUsers = currentRoleUserHash[role].keys
					pickedUserIds = availableUsers[ 0 .. staff -1 ]
				else
					availableUsers = currentRoleUserHash[role].keys
					pickedUserIds = Array.new 
					sourceShiftLastUsrs = unScheduledLstSftUsr[sourceShift][role].select { |uid, schDt| schDt.blank? || schDt > (from - 7.days)}
					targetShiftLastUsrs = unScheduledLstSftUsr[shift][role].select { |uid, schDt| schDt.blank? || schDt > (from - 7.days)}
					
					# Sort the users Ascending order by last working date on the target shift
					# Pick the least recently working staff on the target shift from source shift until reach the minimum staff move count
					targetShftLastUsersAsc = unScheduledLstSftUsr[shift][role].sort_by { |uid, schDt| schDt || Date.new(1900) }
					targetShftLastUsersAsc.each do |id, schDt|
						pickedUserIds << id if sourceShiftLastUsrs.has_key?(id) && currentRoleUserHash[role].has_key?(id)
						break if pickedUserIds.length == minStaffMoveHash[role]
					end
					
					# if not matched number of users worked on the last week then pick the users from the last week staff on source shift
					# Pick the least recently working staff on the target shift from source shift
					unless pickedUserIds.length == minStaffMoveHash[role]
						sourceShiftLastUsrs.each do |userId, schdt|
							pickedUserIds << userId if currentRoleUserHash[role].has_key?(userId)
							break if pickedUserIds.length == minStaffMoveHash[role]
						end
					end
					targetShiftLastUsrs.except!(*pickedUserIds)
					
					# After the minimum staff move then keep some staff from the same shift(Target shift)
					additionalCount = staff-pickedUserIds.length
					if additionalCount>0
						unless pickedUserIds.length == staff
							targetShiftLastUsrs.each do |userId, schdt|
								pickedUserIds << userId if currentRoleUserHash[role].has_key?(userId)
								break if pickedUserIds.length == staff
							end
						end
					end
				end
				pickedUsersHash = currentRoleUserHash[role].select {|k,v| pickedUserIds.include? k }
				scheduledUserIds = scheduledUserIds + pickedUserIds
				if allocatedHash[shift].blank?
					allocatedHash[shift] = { role => pickedUsersHash} 
				else
					allocatedHash[shift].store(role, pickedUsersHash)
				end
				currentRoleUserHash[role].except!( *pickedUserIds ) 
			end
		end
		saveSchedules(allocatedHash, from, to, lastDayOffHash)
	end
	
	# Return active users role wise
	# roleUserHash key as roll_id , value as userHash ( userId as key userObj as value)
	def getRoleWiseUser(locationId, deptId)
		users = User.includes(:wk_user).where(:wk_users => {:location_id => locationId, :department_id => deptId, :termination_date => nil})
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
		if deptId.blank?
			shiftRoles = WkShiftRole.where(:location_id => locationId)
		else
			shiftRoles = WkShiftRole.where(:location_id => locationId, :department_id => deptId)
		end
		reqStaffHash = Hash.new
		shiftRoles.each do |entry|
			if reqStaffHash[entry.shift_id].blank?
				reqStaffHash[entry.shift_id] = { entry.role_id => getReqStaffWithDayOff(entry.staff_count, interval)}
			else
				reqStaffHash[entry.shift_id].store(entry.role_id, getReqStaffWithDayOff(entry.staff_count, interval))
			end
		end
		reqStaffHash
	end
	
	# Return required number of staff with inclusive of day off 
	def getReqStaffWithDayOff(actualRequiremnt, interval)
		dayOffCount = getDayOffCount
		requiredStaff = ((actualRequiremnt*interval).to_f/(interval-dayOffCount).to_f).ceil
		requiredStaff
	end
	
	# return number of days between two dates
	def getDaysBetween(from, to)
		(to - from).to_i + 1
	end
	
	# Save the scheduled hash entries
	def saveSchedules(allocatedHash, from, to, lastDayOffHash)
		allocatedHash.each do |shiftId, pickedRolehash|
			pickedRolehash.values.each do |pickedUsers|
				dayOffs = getDayOffs(pickedUsers.keys, from, to, lastDayOffHash)
				pickedUsers.each do |userId, userObj|
					from.upto(to) do |shiftDate|
						schedule = WkShiftSchedule.where(:schedule_date => shiftDate, :user_id => userId).first_or_initialize(:schedule_date => shiftDate, :user_id => userId)
						if dayOffs[userId].include? shiftDate
							schedule.schedule_as = 'D'
						else
							schedule.schedule_as = 'W'
						end
						schedule.shift_id = shiftId
						schedule.save
					end
				end
			end
		end
	end
	
	# return the day Off schedules for the users
	def getDayOffs(userIdsArr, from, to, lastDayOff)
		dayOffCount = getDayOffCount
		dayOffHash = Hash.new
		# period = "W"
		# isConsecutive = true
		# userLastDayOff = lastDayOff.select { |userId, dayOff| userIdsArr.include? userId }
		# sortedUserLastDayOff = lastDayOff.sort_by { |uid, schDt| schDt || Date.new(1900) }
		noOfDays = getDaysBetween(from, to)#(to - from).to_i + 1 
		# noOfUsers = userIdsArr.length
		# minLeaveUsrPerDay = (noOfUsers * dayOffCount) / 7
		# maxLeaveUsrPerDay = minLeaveUsrPerDay + 1
		# noOfDaysHasMaxLeave = (noOfUsers * dayOffCount) % 7
		# nextDate = from
		# interval = 1
		userIdsArr.each_with_index do |userId, index|
			dayOffArr = Array.new
			#firstLeaveDt = from + ((index * dayOffCount) % noOfDays).days
			for dof in 0..dayOffCount-1
				dayOffArr << from + (((index * dayOffCount) + dof) % noOfDays).days
			end
			dayOffHash[userId] = dayOffArr
			
		end
		dayOffHash
	end
	
	# Return day off count per period
	def getDayOffCount
		2
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
			" inner join wk_users wu on (wu.user_id = u.id and wu.termination_date is null)" +
			joinShiftStr +
			" left join" +
			" (select user_id #{shift}, max(schedule_date) as last_schedule_date from wk_shift_schedules where schedule_as = '#{scheduleAs}' and schedule_date < '#{from}' group by user_id #{shift}) ls on (ls.user_id = u.id #{joinCond})" 
		
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
				minStaffMoveHash[role] = staff if minStaffMoveHash[role].blank? || minStaffMoveHash[role] > staff
			end
		end
		minStaffMoveHash
	end
end
