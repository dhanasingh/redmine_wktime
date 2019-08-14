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

class WkexpenseController < WktimeController	
  unloadable  
  
  menu_item :issues
  before_action :find_optional_project, :only => [:reportdetail, :report]
  
  accept_api_auth :reportdetail, :index, :edit, :update, :destroy , :deleteEntries
  
  include WkexpenseHelper
  include SortHelper  
  helper :sort 


  def getLabelforSpField
	l(:field_amount)
  end
  
  def getCFInRowHeaderHTML
    "wkexpense_cf_in_row_header"
  end
  
  def getCFInRowHTML
    "wkexpense_cf_in_row"
  end
  
  def getTFSettingName
	"wkexpense_issues_filter_tracker"
  end
  
  def filterTrackerVisible
	false
  end
  
  def showSpentFor
	false
  end
  
  def getUnit(entry)
	entry.nil? ? number_currency_format_unit : entry[:currency]
  end
  
  def getUnitDDHTML
	"wkexpense_currency"
  end
  
  def getUnitLabel
	l(:label_wk_currency)
  end
  
  def showWorktimeHeader
	false
  end 
  
  def enterCustomFieldInRow(row)
	false
  end 
  
  def maxHour
	0
  end
  def minHour
	0
  end
  
  def total_all(total)
	total.nil? ? html_hours("%.2f" % 0.00) : html_hours("%.2f" % total)
  end
  
   def report
	@query = WkExpenseEntryQuery.build_from_params(params, :project => @project, :name => '_')
    scope = expense_entry_scope
    @report = WkexpenseHelper::WKExpenseReport.new(@project, @issue, params[:criteria], params[:columns], scope)	
    respond_to do |format|
      format.html { render :layout => !request.xhr? }
      format.csv  { send_data(report_to_csv(@report), :type => 'text/csv; header=present', :filename => 'wkexpense.csv') }
    end
  end 
  
  def deleteEntry
	respond_to do |format|
		format.html {	
			if delete(params[:id])
				flash[:notice] = l(:notice_successful_delete)
			else
				flash[:error] = l(:error_expense_entry_delete)
			end
			redirect_to :action => 'reportdetail', :project_id => params[:project]
		} 		
	end
  end
 
  def textfield_size
	6
  end
	
  def showClockInOut
	false
  end
  
  def getNewCustomField
	nil
  end
  
  def getTELabel
	l(:label_wk_expensesheet)
  end
  
  def maxHourPerWeek
	0
  end
	
  def minHourPerWeek
	0
  end
private
  def getSpecificField
	"amount"
  end

  def getEntityNames
	["#{Wkexpense.table_name}", "#{WkExpenseEntry.table_name}"]
  end
  
  def getQuery(teQuery, ids, from, to, status)
		spField = getSpecificField()
		dtRangeForUsrSqlStr =  "(" + getAllWeekSql(from, to) + ") tmp1"			
		teSqlStr = "(" + teQuery + ") tmp2"
		query = "select tmp3.user_id as user_id , tmp3.spent_on as spent_on, tmp3.#{spField} as #{spField}, tmp3.status as status, tmp3.status_updater as status_updater, tmp3.created_on as created_on, tmp3.currency as currency from (select tmp1.id as user_id, tmp1.created_on, tmp1.selected_date as spent_on, " +
				"case when tmp2.#{spField} is null then 0 else tmp2.#{spField} end as #{spField}, " +
				"case when tmp2.status is null then 'e' else tmp2.status end as status, tmp2.currency, tmp2.status_updater from "
		query = query + dtRangeForUsrSqlStr + " left join " + teSqlStr
		query = query + " on tmp1.id = tmp2.user_id and tmp1.selected_date = tmp2.spent_on where tmp1.id in (#{ids}) ) tmp3 "
		query = query + " left outer join (select min( #{getDateSqlString('t.spent_on')} ) as min_spent_on, t.user_id as usrid from wk_expense_entries t, users u "
    query = query + " where u.id = t.user_id and u.id in (#{ids}) group by t.user_id ) vw on vw.usrid = tmp3.user_id "
		query = query + " left join users AS un on un.id = tmp3.user_id "
		query = query + getWhereCond(status)
	end
  
  def findBySql(query) 
	spField = getSpecificField()
	result = WkExpenseEntry.find_by_sql("select count(*) as id from (" + query + ") as v2")
	@entry_count = result[0].id	
	setLimitAndOffset()	
	rangeStr = formPaginationCondition()
	@entries = WkExpenseEntry.find_by_sql(query + rangeStr)
	@unit = @entries.blank? ? number_currency_format_unit : @entries[0][:currency]
	result = WkExpenseEntry.find_by_sql("select sum(v2." + spField + ") as " + spField + " from (" + query + ") as v2")	
	@total_hours = result[0].amount
  end
  
  def getTEAllTimeRange(ids)
	teQuery = "select v.startday as startday from (select #{getDateSqlString('t.spent_on')} as startday " +
				"from wk_expense_entries t where user_id in (#{ids})) v group by v.startday order by v.startday"
	teResult = WkExpenseEntry.find_by_sql(teQuery)
  end
  
  def findWkTEByCond(cond)
	@wktimes = Wkexpense.where(cond)
  end
  
  def findEntriesByCond(cond)
	#WkExpenseEntry.joins(:project).joins(:activity).joins("LEFT OUTER JOIN issues ON issues.id = wk_expense_entries.issue_id").where(cond).order('projects.name, issues.subject, enumerations.name, wk_expense_entries.spent_on')
	@renderer.getSheetEntries(cond, WkExpenseEntry, getFiletrParams)
  end
  
  def setValueForSpField(teEntry,spValue,decimal_separator,entry)
	teEntry.amount = spValue.blank? ? nil : spValue.gsub(decimal_separator, '.').to_f
	teEntry.currency = getUnit(entry)
  end
  
  def getWkEntity
	Wkexpense.new 
  end
  
  def getTEEntry(id)
	id.blank? ? WkExpenseEntry.new : WkExpenseEntry.find(id)
  end
  
  def deleteWkEntity(cond) 
	Wkexpense.where(cond).delete_all
  end 
  
  def delete(ids)
	#WkExpenseEntry.delete(ids)
	errMsg = false
	@expense_entries = WkExpenseEntry.where(:id => ids)#WkExpenseEntry.find_by_sql("SELECT * FROM wk_expense_entries w where id = #{ids} ;")
	destroyed = WkExpenseEntry.transaction do
		@expense_entries.each do |t|
			status = getExpenseEntryStatus(t.spent_on, t.user_id)
			if !status.blank? && ('a' == status || 's' == status || 'l' == status)					
				 errMsg = false 
			else
				errMsg = true
				WkExpenseEntry.delete(ids)
				break
			end		
		end
	end
	errMsg
  end
  
  def getExpenseEntryStatus(spent_on, user_id)
		start_day = getStartDay(spent_on)
		result = Wkexpense.where(['begin_date = ? AND user_id = ?', start_day, user_id])
		result = result[0].blank? ? 'n' : result[0].status
		return 	result	  
  end
  
  def findTEEntries(ids)
	WkExpenseEntry.find(ids)
  end
  
  def setTotal(wkEntity,total)
	wkEntity.amount = total
  end
  
  def setEntityLabel
	l(:label_wkexpense)
  end
  
  def setTEProjects(projects)	
	expense_project_ids =  Setting.plugin_redmine_wktime['wkexpense_projects']	
	if(!expense_project_ids.blank? && expense_project_ids != [""])
		#expense_projects = Project.find_all_by_id(expense_project_ids)
		expense_projects = Project.find(expense_project_ids) 
		projects = projects & expense_projects
	end	
	projects
  end
  
  def find_optional_project	 
    if !params[:issue_id].blank?
      @issue = Issue.find(params[:issue_id])
      @project = @issue.project
    elsif !params[:project_id].blank?	
      @project = Project.find(params[:project_id])
    end
  end
  
  def validateEntry(stDate)
	errorMsg = nil
  end
  
  def getTEName
	"expense"
  end
  
  # Returns the ExpenseEntry scope for index and report actions
  def expense_entry_scope(options={})
    scope = @query.results_scope(options)
    if @issue
      scope = scope.on_issue(@issue)
    end
    scope
  end
  
  def findTEEntryBySql(query)
	WkExpenseEntry.find_by_sql(query)
  end
  
  def formQuery(wkSelectStr, sqlStr, wkSqlStr)
	query =  wkSelectStr + " ,exp.currency" + sqlStr + " inner join wk_expense_entries exp on v1.id = exp.id " + wkSqlStr
  end
  
  def getUserCFFromSession
	#return user custom field filters from session
	session[:wkexpense][:filters]
  end
  
  def getUserIdFromSession
	#return user_id from session
	session[:wkexpense][:user_id]
  end
  
  def getStatusFromSession
	session[:wkexpense][:status]
  end
  
  def setUserIdsInSession(ids)
	session[:wkexpense][:all_user_ids] = ids
  end
  
  def getUserIdsFromSession
	session[:wkexpense][:all_user_ids]
  end
end
