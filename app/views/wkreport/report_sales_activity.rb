# ERPmine - ERP for service industry
# Copyright (C) 2011-2021 Adhi software pvt ltd
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

module ReportSalesActivity
	include WkcrmHelper

	def calcReportData(userId, groupId, projId, from, to)
		from = from.to_date
		to = to.to_date
		activityList = getActivityList(from, to, groupId, userId)
		activities = {}
		totalTime = 0
		activityList.each do |activity|
			activities[activity.id] = {}
			isSupplier = false
			if activity.parent_type == 'WkAccount'
				isSupplier = true unless activity.parent.account_type == 'A'
			elsif activity.parent_type == 'WkCrmContact'
				isSupplier = true unless activity.parent.contact_type == 'C'
			end
			unless isSupplier
				completionTime = (activity.status == 'C' || activity.status == 'H') ? convertSecToDays(activity.status_update_on - activity.start_date) : nil 
				totalTime = totalTime + (completionTime || 0)
				activities[activity.id]['type'] = acttypeHash[activity.activity_type]
				activities[activity.id]['name'] = activity.name
				activities[activity.id]['status'] = activity.activity_type == 'M' || activity.activity_type == 'C' ? meetCallStatusHash[activity.status] : taskStatusHash[activity.status]
				activities[activity.id]['parent_type'] = relatedHash[activity.parent_type]
				activities[activity.id]['parent_name'] = activity.parent&.name || ''
				activities[activity.id]['start_date'] = activity.start_date.localtime.strftime("%Y-%m-%d %H:%M:%S")
				activities[activity.id]['complete_date'] = activity.status == 'C' || activity.status == 'H' ? activity.status_update_on.localtime.strftime("%Y-%m-%d %H:%M:%S") : ''
				activities[activity.id]['assigned_user'] = activity.assigned_user&.name || ''
				activities[activity.id]['duration'] = completionTime
			end
		end
		stock = {activities: activities, totDuration: (totalTime/activityList.length).round(2).to_s + " " + l(:label_day_plural), from: from.to_formatted_s(:long), to: to.to_formatted_s(:long)}
		stock
	end
end