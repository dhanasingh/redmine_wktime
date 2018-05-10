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

class SheetViewRenderer
	attr_accessor :issue_join_cond, :spent_for_join, :spent_for_cond
	
	def self.getInstance(sheetType)
		renderer = nil
		case sheetType
		when "I"
			renderer = DayViewRenderer.new()
		when "W"
			renderer = WeeklyViewRenderer.new()
		end
		renderer
	end
	
	def getDaysPerSheet
	end
	
	def showWorkTimeHeader
	end
	
	def showTEStatus
	end
	
	def showSpentOnInRow
	end
	
	def getSheetType
	end
	
	def getSheetEntries(cond, modelClass, givenValues)
	end
	
	def getEntrySpentFor(entry)
	end
	
	def getStartOfSheet(startDate)
	end
	
	def useSelectedDtAsStart
	end
end
