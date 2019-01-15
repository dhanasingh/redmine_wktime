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

class WeeklyViewRenderer < SheetViewRenderer
	def getDaysPerSheet
		7
	end
	
	def showWorkTimeHeader
		true
	end
	
	def showTEStatus
		true
	end
	
	def showSpentOnInRow
		false
	end
	
	def getSheetType
		'W'
	end
	
	def getSheetEntries(cond, modelClass, givenValues)
		modelClass.joins(:project).joins(:activity).joins("LEFT OUTER JOIN issues ON issues.id = #{modelClass.table_name}.issue_id").where(cond).order("projects.name, issues.subject, enumerations.name, #{modelClass.table_name}.spent_on")
	end
	
	def getEntrySpentFor(entry)
		parentId = nil
		parentType = nil
		unless entry.spent_for.blank?
			parentId = entry.spent_for.spent_for_id 
			parentType = entry.spent_for.spent_for_type
		end
		{:parent_id => parentId, :parent_type => parentType}
	end
	
	def getStartOfSheet(startDate)
		nil
	end
	
	def useSelectedDtAsStart
		false
	end
end
