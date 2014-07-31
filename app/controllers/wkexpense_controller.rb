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
	sort_init 'spent_on', 'desc'
    sort_update 'spent_on' => ['spent_on', "#{WkExpenseEntry.table_name}.created_on"],
                'user' => 'user_id',
                'activity' => 'activity_id',
                'project' => "#{Project.table_name}.name",
                'issue' => 'issue_id',
                'amount' => 'amount'

    retrieve_date_range
	@from = getStartDay(@from)
	@to = getEndDay(@to)
    wkexpense = WkExpenseEntry.visible.spent_between(@from, @to)
    if @issue
      wkexpense = wkexpense.on_issue(@issue)
    elsif @project		  
      wkexpense = wkexpense.on_project(@project, Setting.display_subprojects_issues?)	  
    end
    respond_to do |format|
      format.html {
        # Paginate results
        @entry_count = wkexpense.count
        @entry_pages = Paginator.new self, @entry_count, per_page_option, params['page']		
        @entries = wkexpense.all(
          :include => [:project, :activity, :user, {:issue => :tracker}],
          :order => sort_clause,
          :limit  =>  @entry_pages.items_per_page,
          :offset =>  @entry_pages.current.offset
        )
        @total_amount = wkexpense.sum(:amount).to_f
        render :layout => !request.xhr?
      }
      format.api  {
        @entry_count = wkexpense.count
        @offset, @limit = api_offset_and_limit
        @entries = wkexpense.all(
          :include => [:project, :activity, :user, {:issue => :tracker}],
          :order => sort_clause,
          :limit  => @limit,
          :offset => @offset
        )
      }
      format.atom {
        entries = wkexpense.all(
          :include => [:project, :activity, :user, {:issue => :tracker}],
          :order => "#{WkExpenseEntry.table_name}.created_on DESC",
          :limit => Setting.feeds_limit.to_i
        )	
        render_feed(entries, :title => l(:label_spent_expense))
      }
      format.csv {
        # Export all entries
        @entries = wkexpense.all(
          :include => [:project, :activity, :user, {:issue => [:tracker, :assigned_to, :priority]}],
          :order => sort_clause
        )
        send_data(entries_to_csv(@entries), :type => 'text/csv; header=present', :filename => 'wkexpense.csv')
      }
    end 
	
  end
  
   def report   
	retrieve_date_range
    @report = WkexpenseHelper::WKExpenseReport.new(@project, @issue, params[:criteria], params[:columns], @from, @to)

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
	result = WkExpenseEntry.find_by_sql("select count(*) as id from (" + selectStr + sqlStr + ") as v2")
	@entry_count = result[0].id
	
	setLimitAndOffset()	
	rangeStr = formPaginationCondition()

	@entries = WkExpenseEntry.find_by_sql(wkSelectStr + " ,exp.currency" + sqlStr + 
			" inner join wk_expense_entries exp on v1.id = exp.id " + wkSqlStr + rangeStr)			

	@unit = @entries.blank? ? l('number.currency.format.unit') : @entries[0][:currency]
	
	#@total_hours = TimeEntry.visible.sum(:hours, :include => [:user], :conditions => cond.conditions).to_f
		
	result = WkExpenseEntry.find_by_sql("select sum(v2." + spField + ") as " + spField + " from (" + selectStr + sqlStr + ") as v2")	
	@total_hours = result[0].amount
  end
  
  def findWkTEByCond(cond)
	@wktimes = Wkexpense.find(:all, :conditions => cond)
  end
  
  def findEntriesByCond(cond)
	WkExpenseEntry.find(:all, :conditions => cond,
		:order => 'project_id, issue_id, activity_id, spent_on')
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
		expense_projects = Project.find_all_by_id(expense_project_ids) 
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
end
