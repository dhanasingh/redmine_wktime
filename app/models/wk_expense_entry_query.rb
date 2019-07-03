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

class WkExpenseEntryQuery < Query

  self.queried_class = WkExpenseEntry
  self.view_permission = :view_time_entries
  
  self.available_columns = [
    QueryColumn.new(:project, :sortable => "#{Project.table_name}.name", :groupable => true),
    QueryColumn.new(:spent_on, :sortable => ["#{WkExpenseEntry.table_name}.spent_on", "#{WkExpenseEntry.table_name}.created_on"], :default_order => 'desc', :groupable => true),
    QueryColumn.new(:tweek, :sortable => ["#{WkExpenseEntry.table_name}.spent_on", "#{WkExpenseEntry.table_name}.created_on"], :caption => l(:label_week)),
    QueryColumn.new(:user, :sortable => lambda {User.fields_for_order_statement}, :groupable => true),
    QueryColumn.new(:activity, :sortable => "#{TimeEntryActivity.table_name}.position", :groupable => true),
    QueryColumn.new(:issue, :sortable => "#{Issue.table_name}.id"),
    QueryAssociationColumn.new(:issue, :tracker, :caption => :field_tracker, :sortable => "#{Tracker.table_name}.position"),
    QueryAssociationColumn.new(:issue, :status, :caption => :field_status, :sortable => "#{IssueStatus.table_name}.position"),
    QueryColumn.new(:comments),
	QueryColumn.new(:currency),
	QueryColumn.new(:amount, :sortable => "#{WkExpenseEntry.table_name}.amount", :totalable => true),
  ]

  def initialize(attributes=nil, *args)
    super attributes
    self.filters ||= { 'spent_on' => {:operator => "*", :values => []} }
  end

  def initialize_available_filters
    add_available_filter "spent_on", :type => :date_past

    add_available_filter("project_id",
      :type => :list, :values => lambda { project_values }
    ) if project.nil?

    if project && !project.leaf?
      add_available_filter "subproject_id",
        :type => :list_subprojects,
        :values => lambda { subproject_values }
    end

    add_available_filter("issue_id", :type => :tree, :label => :label_issue)
    add_available_filter("issue.tracker_id",
      :type => :list,
      :name => l("label_attribute_of_issue", :name => l(:field_tracker)),
      :values => lambda { trackers.map {|t| [t.name, t.id.to_s]} })
    add_available_filter("issue.status_id",
      :type => :list,
      :name => l("label_attribute_of_issue", :name => l(:field_status)),
      :values => lambda { issue_statuses_values })
    add_available_filter("issue.fixed_version_id",
      :type => :list,
      :name => l("label_attribute_of_issue", :name => l(:field_fixed_version)),
      :values => lambda { fixed_version_values })

    add_available_filter("user_id",
      :type => :list_optional, :values => lambda { author_values }
    )

    activities = (project ? project.activities : TimeEntryActivity.shared)
    add_available_filter("activity_id",
      :type => :list, :values => activities.map {|a| [a.name, a.id.to_s]}
    )

    add_available_filter "comments", :type => :text
    add_available_filter "amount", :type => :float

    # add_custom_fields_filters(TimeEntryCustomField)
    # add_associations_custom_fields_filters :project
    # add_custom_fields_filters(issue_custom_fields, :issue)
    # add_associations_custom_fields_filters :user
  end

  def available_columns
    return @available_columns if @available_columns
    @available_columns = self.class.available_columns.dup
    # @available_columns += TimeEntryCustomField.visible.
                            # map {|cf| QueryCustomFieldColumn.new(cf) }
    # @available_columns += issue_custom_fields.visible.
                            # map {|cf| QueryAssociationCustomFieldColumn.new(:issue, cf, :totalable => false) }
    # @available_columns += ProjectCustomField.visible.
                            # map {|cf| QueryAssociationCustomFieldColumn.new(:project, cf) }
    @available_columns
  end

  def default_columns_names
	@default_columns_names ||= begin
      default_columns = [:spent_on, :user, :activity, :issue, :comments, :currency, :amount]

      project.present? ? default_columns : [:project] | default_columns
    end
  end
  
  def default_totalable_names
    [:amount]
  end
  
  def default_sort_criteria
    [['spent_on', 'desc']]
  end

  # If a filter against a single issue is set, returns its id, otherwise nil.
  def filtered_issue_id
    if value_for('issue_id').to_s =~ /\A(\d+)\z/
      $1
    end
  end
  
  # Returns sum of all the spent amount
  def total_for_amount(scope)
    map_total(scope.sum(:amount)) {|t| t.to_f.round(2)}
  end

  def base_scope
    WkExpenseEntry.visible.
      joins(:project, :user).
      includes(:activity).
      references(:activity).
      left_join_issue.
      where(getSupervisorCondStr)
  end
  
  def getSupervisorCondStr
	orgCondStatement = statement
	condStatement = orgCondStatement
	
	wktime_helper = Object.new.extend(WktimeHelper)
	valid_ERP_perm = wktime_helper.validateERPPermission('A_TE_PRVLG')
	isSupervisor = wktime_helper.isSupervisor
	projectIdArr = wktime_helper.getManageProject()
	isManager = projectIdArr.blank? ? false : true
	
	if isSupervisor && !valid_ERP_perm && !User.current.admin?
		userIdArr = Array.new
		user_cond = ""
		rptUsers = wktime_helper.getReportUsers(User.current.id)
		userIdArr = rptUsers.collect(&:id) if !rptUsers.blank?
		userIdArr = userIdArr << User.current.id.to_s
		userIds = "#{userIdArr.join(',')}"
		user_cond = "#{WkExpenseEntry.table_name}.user_id IN (#{userIds})"
		
		if condStatement.blank?
			condStatement = "(#{user_cond})" if !user_cond.blank?
		else				
			if filters["user_id"].blank?			
				condStatement = user_cond.blank? ? condStatement : condStatement + " AND (#{user_cond})"
			else
				user_id = filters["user_id"][:values]
				userIdStrArr = userIdArr.collect{|i| i.to_s}
				filterUserIds = userIdStrArr & filters["user_id"][:values]
				
				if !filterUserIds.blank?
					if user_id.is_a?(Array) && user_id.include?("me")
						filterUserIds << (User.current.id).to_s
					end
					filters["user_id"][:values] = filterUserIds
					condStatement = statement
					filters["user_id"][:values] = user_id #Setting the filter values to retain the filter on page
				else
					if user_id.is_a?(Array) && user_id.include?("me")
						filters["user_id"][:values] = [User.current.id.to_s]
						condStatement = statement
						filters["user_id"][:values] = user_id
					else
						condStatement = "1=0"
					end
				end
			end
		end
		if isManager
			mgrCondStatement = ""
			if !orgCondStatement.blank?
				mgrCondStatement = orgCondStatement + " AND "
			end
			mgrCondStatement = mgrCondStatement + "(#{WkExpenseEntry.table_name}.project_id in (" + projectIdArr.collect{|i| i.to_s}.join(',') + "))"
			condStatement = condStatement.blank? ? condStatement : "(" + condStatement + ") OR (" + mgrCondStatement + ")"
		end
	else
		#if (!Setting.plugin_redmine_wktime['ftte_view_only_own_spent_time'].blank? && 
		#Setting.plugin_redmine_wktime['ftte_view_only_own_spent_time'].to_i == 1) && 
		if !valid_ERP_perm && !User.current.admin? && !isManager
			condStatement = condStatement.blank? ? condStatement : condStatement + " AND (#{WkExpenseEntry.table_name}.user_id = " + User.current.id.to_s + ")"
		elsif isManager && !valid_ERP_perm && !User.current.admin?
			user_id = filters["user_id"][:values] if !filters["user_id"].blank?
			if !user_id.blank? && user_id.is_a?(Array) && (user_id.include?("me") || user_id.include?(User.current.id.to_s))
				condStatement = condStatement
			else
				condStatement = condStatement.blank? ? condStatement : "(" + condStatement + ") AND (#{WkExpenseEntry.table_name}.project_id in (" + projectIdArr.collect{|i| i.to_s}.join(',') + "))"
			end
		end
	end
	condStatement
  end

  def results_scope(options={})
    order_option = [group_by_sort_order, (options[:order] || sort_clause)].flatten.reject(&:blank?)

    base_scope.
      order(order_option).
      joins(joins_for_order_statement(order_option.join(',')))
  end   

  def sql_for_issue_id_field(field, operator, value)
    case operator
    when "="
      "#{WkExpenseEntry.table_name}.issue_id = #{value.first.to_i}"
    when "~"
      issue = Issue.where(:id => value.first.to_i).first
      if issue && (issue_ids = issue.self_and_descendants.pluck(:id)).any?
        "#{WkExpenseEntry.table_name}.issue_id IN (#{issue_ids.join(',')})"
      else
        "1=0"
      end
    when "!*"
      "#{WkExpenseEntry.table_name}.issue_id IS NULL"
    when "*"
      "#{WkExpenseEntry.table_name}.issue_id IS NOT NULL"
    end
  end

  def sql_for_issue_fixed_version_id_field(field, operator, value)
   issue_ids = Issue.where(:fixed_version_id => value.map(&:to_i)).pluck(:id)
    case operator
    when "="
      if issue_ids.any?
        "#{WkExpenseEntry.table_name}.issue_id IN (#{issue_ids.join(',')})"
      else
        "1=0"
      end
    when "!"
      if issue_ids.any?
        "#{WkExpenseEntry.table_name}.issue_id NOT IN (#{issue_ids.join(',')})"
      else
        "1=1"
      end
    end
  end

  def sql_for_activity_id_field(field, operator, value)
    condition_on_id = sql_for_field(field, operator, value, Enumeration.table_name, 'id')
    condition_on_parent_id = sql_for_field(field, operator, value, Enumeration.table_name, 'parent_id')
    ids = value.map(&:to_i).join(',')
    table_name = Enumeration.table_name
    if operator == '='
      "(#{table_name}.id IN (#{ids}) OR #{table_name}.parent_id IN (#{ids}))"
    else
      "(#{table_name}.id NOT IN (#{ids}) AND (#{table_name}.parent_id IS NULL OR #{table_name}.parent_id NOT IN (#{ids})))"
    end
  end

  def sql_for_issue_tracker_id_field(field, operator, value)
    sql_for_field("tracker_id", operator, value, Issue.table_name, "tracker_id")
  end

  def sql_for_issue_status_id_field(field, operator, value)
    sql_for_field("status_id", operator, value, Issue.table_name, "status_id")
  end

  # Accepts :from/:to params as shortcut filters
  def build_from_params(params, defaults={})
    super
    if params[:from].present? && params[:to].present?
      add_filter('spent_on', '><', [params[:from], params[:to]])
    elsif params[:from].present?
      add_filter('spent_on', '>=', [params[:from]])
    elsif params[:to].present?
      add_filter('spent_on', '<=', [params[:to]])
    end
    self
  end

  def joins_for_order_statement(order_options)
    joins = [super]

    if order_options
      if order_options.include?('issue_statuses')
        joins << "LEFT OUTER JOIN #{IssueStatus.table_name} ON #{IssueStatus.table_name}.id = #{Issue.table_name}.status_id"
      end
      if order_options.include?('trackers')
        joins << "LEFT OUTER JOIN #{Tracker.table_name} ON #{Tracker.table_name}.id = #{Issue.table_name}.tracker_id"
      end
    end

    joins.compact!
    joins.any? ? joins.join(' ') : nil
  end
end
