class WkexpenseController < WktimeController	
  unloadable  
  
  menu_item :issues
  before_filter :find_optional_project, :only => [:reportdetail, :report]
  
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
  
  def getUnit(entry)
	entry.nil? ? l('number.currency.format.unit') : entry[:currency]
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
  
  def maxHour
	0
  end
  def minHour
	0
  end
  
  def total_all(total)
	total.nil? ? html_hours("%.2f" % 0.00) : html_hours("%.2f" % total)
  end
  
  def reportdetail	
	 @query = WkExpenseEntryQuery.build_from_params(params, :project => @project, :name => '_')
	 sort_init(@query.sort_criteria.empty? ? [['spent_on', 'desc']] : @query.sort_criteria)
    sort_update(@query.sortable_columns)
    scope = expense_entry_scope(:order => sort_clause).
      includes(:project, :user, :issue).
      preload(:issue => [:project, :tracker, :status, :assigned_to, :priority])
    respond_to do |format|
      format.html {
        @entry_count = scope.count
        @entry_pages = Paginator.new @entry_count, per_page_option, params['page']
        @entries = scope.offset(@entry_pages.offset).limit(@entry_pages.per_page).to_a
        @total_hours = scope.sum(:amount).to_f
        render :layout => !request.xhr?
      }
      format.api  {
         @entry_count = scope.count
        @offset, @limit = api_offset_and_limit
        @entries = scope.offset(@offset).limit(@limit).preload(:custom_values => :custom_field).to_a
      }
      format.atom {
        entries = scope.limit(Setting.feeds_limit.to_i).reorder("#{WkExpenseEntry.table_name}.created_on DESC").to_a
        render_feed(entries, :title => l(:label_spent_time))
      }
      format.csv {
        # Export all entries
        @entries = scope.to_a
        send_data(query_to_csv(@entries, @query, params), :type => 'text/csv; header=present', :filename => 'expenselog.csv')
      }
    end 
	
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
			delete(params[:id])
			flash[:notice] = l(:notice_successful_delete)
			redirect_to :action => 'reportdetail', :project_id => params[:project]
		} 		
	end
  end
 
private
  def getSpecificField
	"amount"
  end

  def getEntityNames
	["#{Wkexpense.table_name}", "#{WkExpenseEntry.table_name}"]
  end
  
  def findBySql(selectStr,sqlStr,wkSelectStr,wkSqlStr)
	spField = getSpecificField()		
	result = WkExpenseEntry.find_by_sql("select count(*) as id from (" + selectStr + sqlStr + wkSqlStr + ") as v2")
	@entry_count = result[0].id
	
	setLimitAndOffset()	
	rangeStr = formPaginationCondition()

	@entries = WkExpenseEntry.find_by_sql(wkSelectStr + " ,exp.currency" + sqlStr + 
			" inner join wk_expense_entries exp on v1.id = exp.id " + wkSqlStr + rangeStr)			

	@unit = @entries.blank? ? l('number.currency.format.unit') : @entries[0][:currency]
	
	#@total_hours = TimeEntry.visible.sum(:hours, :include => [:user], :conditions => cond.conditions).to_f
		
	result = WkExpenseEntry.find_by_sql("select sum(v2." + spField + ") as " + spField + " from (" + selectStr + sqlStr + wkSqlStr +") as v2")	
	@total_hours = result[0].amount
  end
  
  def findWkTEByCond(cond)
	#@wktimes = Wkexpense.find(:all, :conditions => cond)
	@wktimes = Wkexpense.where(cond)
  end
  
  def findEntriesByCond(cond)
	#WkExpenseEntry.find(:all, :conditions => cond, :order => 'project_id, issue_id, activity_id, spent_on')
	#WkExpenseEntry.where(cond).order('project_id, issue_id, activity_id, spent_on')
	WkExpenseEntry.joins(:project).joins(:activity).joins("LEFT OUTER JOIN issues ON issues.id = wk_expense_entries.issue_id").where(cond).order('projects.name, issues.subject, enumerations.name, wk_expense_entries.spent_on')
  end
  
  def setValueForSpField(teEntry,spValue,decimal_separator,entry)
	teEntry.amount = spValue.blank? ? nil : spValue.gsub(decimal_separator, '.').to_f
	teEntry.currency = getUnit(entry)
  end
  
  def getNewCustomField
	nil
  end
  
  def getWkEntity
	Wkexpense.new 
  end
  
  def getTEEntry(id)
	id.blank? ? WkExpenseEntry.new : WkExpenseEntry.find(id)
  end
  
  def deleteWkEntity(cond) 
	Wkexpense.delete_all(cond)
  end 
  
  def delete(ids)
	WkExpenseEntry.delete(ids)
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
end
