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

class ScheduleStrategy
  include ApplicationHelper
  include Redmine::Utils::DateCalculation
  
	def initialize
		@strategies = {}
		@strategies['P'] = PrioritySchedule.new
		@strategies['RR'] = RoundRobinSchedule.new
	end

	def schedule(strategyName, locationId, deptId, from, to)
		strategy = @strategies[strategyName]
		intervalType = getIntervalType
		intervalVal = getIntervalValue(intervalType)
		startDate = from
		if intervalType == 'M'
			startDate = from.at_beginning_of_month
		else
			#intervalVal = 7
			startDate = getStartDay(from)
		end
		if startDate < Date.today
			startDate = getStartDay(Date.today + 7.days)
		end
		intervals = getIntervals(startDate, to, intervalVal, intervalType)
		intervals.each do |entry|
			scheduledEntries = strategy.schedule(locationId, deptId, entry[0], entry[1])
		end
		#scheduledEntries = strategy.schedule(locationId, deptId, entry[0], entry[1])
	end
	
	# Return the interval value for the interval
	def getIntervalValue(intervalType)
		intervalVal = 1
		if intervalType == 'W'
			intervalVal = 7
		end
		intervalVal
	end
	
	def getIntervals(from, to, intervalVal, intervalType)
		intervals = Array.new
		nextStart = from
		if intervalType == 'M'
			until nextStart > to
				intervals << [nextStart, (nextStart + (intervalVal-1).months).at_end_of_month]
				nextStart = nextStart + intervalVal.months
			end
		else
			until nextStart > to
				intervals << [nextStart, nextStart + (intervalVal-1).days]
				nextStart = nextStart + intervalVal.days
			end
		end
		intervals
	end
	
	#change the date to first day of week
	def getStartDay(date)	
		startOfWeek = getStartOfWeek
		#Martin Dube contribution: 'start of the week' configuration
		unless date.nil?			
			#the day of calendar week (0-6, Sunday is 0)			
			dayfirst_diff = (date.wday+7) - (startOfWeek)
			date -= (dayfirst_diff%7)
		end		
		date
	end
	
	#Code snippet taken from application_helper.rb  - include_calendar_headers_tags method
	def getStartOfWeek
		start_of_week = Setting.start_of_week
        start_of_week = l(:general_first_day_of_week, :default => '1') if start_of_week.blank?    
		start_of_week = start_of_week.to_i % 7
	end
	
	# Return the interval type ie, Month, week etc
	def getIntervalType
		# get the interval type from settings
		# currently not implemented. It will useful in future
		intervalType = 'W'
		intervalType
	end
end
