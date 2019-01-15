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

class DayViewRenderer < SheetViewRenderer
	def getDaysPerSheet
		1
	end
	
	def showWorkTimeHeader
		false
	end
	
	def showTEStatus
		false
	end
	
	def showSpentOnInRow
		true
	end
	
	def getSheetType
		'I'
	end
	
	def getSheetEntries(cond, modelClass, givenValues)
		issueCond = ""
		spentForCond = ""
		unless givenValues[:issue_id].blank? || givenValues[:issue_id].to_i <= 0
			issueCond = " AND i.id = #{givenValues[:issue_id]}" 
		end
		unless givenValues[:spent_for_id].blank? || givenValues[:spent_for_type].blank? || givenValues[:spent_for_id] == 0
			spentForCond = " AND ap.parent_type = '#{givenValues[:spent_for_type]}' and ap.parent_id = #{givenValues[:spent_for_id]}" 
		end
		sqlStr = "select i.id as issue_id, i.subject as issue_name, i.project_id, i.assigned_to_id, 
			ap.id as account_project_id, ap.parent_id, ap.parent_type,
			te.id as time_entry_id, te.id, te.user_id, COALESCE(te.spent_on,'#{givenValues[:selected_date]}') as spent_on , COALESCE(te.#{getSpField[modelClass.to_s]},0) as #{getSpField[modelClass.to_s]}, te.activity_id, te.comments, te.spent_on_time, 
			te.spent_for_id, te.spent_for_type, te.spent_id, te.spent_type #{getAdditionalField(modelClass.to_s, 'te')} from issues i " +
			#p.name as project_name, inner join projects p on (p.id = i.project_id and project_id in (#{givenValues[:project_id]}) #{self.issue_join_cond})
			" left join wk_issue_assignees ia on (i.id = ia.issue_id and ia.user_id = #{givenValues[:user_id]} )" + # OR i.assigned_to_id = #{givenValues[:user_id]}
			" left outer join wk_account_projects ap on (ap.project_id = i.project_id)" +
			self.spent_for_join.to_s + 
			" left outer join (select t.*, sf.spent_on_time, sf.spent_for_id, sf.spent_for_type, sf.spent_id, sf.spent_type  from #{modelClass.table_name} t 
			inner join wk_spent_fors sf on (t.id = sf.spent_id and sf.spent_type = '#{modelClass.to_s}' and t.spent_on = '#{givenValues[:selected_date]}')) te on te.issue_id = i.id and te.user_id = #{givenValues[:user_id]}
			and COALESCE(te.spent_for_type,'') = COALESCE(ap.parent_type,'') and COALESCE(te.spent_for_id, 0) = COALESCE(ap.parent_id, 0)" 
			#time_entries te on te.spent_on = '#{@selectedDate}' and te.issue_id = i.id and te.user_id = #{@user.id} 
			#left outer join wk_spent_fors sf on sf.spent_type = 'TimeEntry' and sf.spent_for_type = ap.parent_type and sf.spent_for_id = ap.parent_id
		sqlStr = sqlStr + " Where (ia.id IS NOT NULL OR te.id IS NOT NULL OR i.assigned_to_id = #{givenValues[:user_id]} )" 
		sqlStr = sqlStr + issueCond + spentForCond + self.issue_join_cond.to_s + spent_for_cond.to_s
		#sqlStr = sqlStr + " Where "
		modelClass.find_by_sql(sqlStr)
	end
	
	def getEntrySpentFor(entry)
		parentId = nil
		parentType = nil
		spentOnTime = Time.now
		if entry.spent_for.blank? && !entry.hours.blank? && entry.id.blank?
			parentId = entry.parent_id
			parentType = entry.parent_type
			spentOnTime = entry.spent_on_time
		elsif !entry.spent_for.blank?
			parentId = entry.spent_for.spent_for_id 
			parentType = entry.spent_for.spent_for_type
			spentOnTime = entry.spent_for.spent_on_time
		end
		{:parent_id => parentId, :parent_type => parentType, :spent_on_time => spentOnTime}
	end
	
	def getStartOfSheet(startDate)
		startDate.wday
	end
	
	def useSelectedDtAsStart
		true
	end
	
	def getSpField
		{"WkExpenseEntry" => 'amount', "TimeEntry" => 'hours'}
	end
	
	def getAdditionalField(modelName, aliasName)
		modelName == "WkExpenseEntry" ? " ,#{aliasName}.currency" : ""
	end
end
