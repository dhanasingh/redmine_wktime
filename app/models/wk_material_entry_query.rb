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

class WkMaterialEntryQuery < Query

  self.queried_class = WkMaterialEntry
  self.view_permission = :view_time_entries

  self.available_columns = [
    QueryColumn.new(:project, :sortable => "#{Project.table_name}.name", :groupable => true),
    QueryColumn.new(:spent_on, :sortable => ["#{WkMaterialEntry.table_name}.spent_on", "#{WkMaterialEntry.table_name}.created_on"], :default_order => 'desc', :groupable => true),
    QueryColumn.new(:tweek, :sortable => ["#{WkMaterialEntry.table_name}.spent_on", "#{WkMaterialEntry.table_name}.created_on"], :caption => l(:label_week)),
    QueryColumn.new(:user, :sortable => lambda {User.fields_for_order_statement}, :groupable => true),
    QueryColumn.new(:activity, :sortable => "#{TimeEntryActivity.table_name}.position", :groupable => true),
    QueryColumn.new(:issue, :sortable => "#{Issue.table_name}.id"),
    QueryAssociationColumn.new(:issue, :tracker, :caption => :field_tracker, :sortable => "#{Tracker.table_name}.position"),
    QueryAssociationColumn.new(:issue, :status, :caption => :field_status, :sortable => "#{IssueStatus.table_name}.position"),
    QueryColumn.new(:comments),
	QueryColumn.new(:inventory_item_id),
    QueryColumn.new(:quantity, :sortable => "#{WkMaterialEntry.table_name}.quantity", :totalable => true),
	QueryColumn.new(:currency),
	QueryColumn.new(:selling_price, :sortable => "#{WkMaterialEntry.table_name}.selling_price", :totalable => true),
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
    add_available_filter "quantity", :type => :float
  end

  def available_columns
    return @available_columns if @available_columns
    @available_columns = self.class.available_columns.dup
    @available_columns
  end

  def default_columns_names
	@default_columns_names ||= begin
      default_columns = [:spent_on, :user, :activity, :issue, :comments, :inventory_item_id, :quantity, :currency, :selling_price]

      project.present? ? default_columns : [:project] | default_columns
    end
  end

  def default_totalable_names
    [:quantity, :selling_price]
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

  def base_scope
    product_type = nil
    if filters.key?("product_type").present?
      product_type = filters["product_type"]["values"]
      filters.delete("product_type")
    end
    scope = WkMaterialEntry.visible.
      joins(:project, :user).
      includes(:activity).
	    includes(:inventory_item).
      references(:activity).
      left_join_issue
    scope = scope.where("wk_inventory_items.product_type ='#{product_type}'") if product_type.present?
    scope.where(statement)
  end

  def results_scope(options={})
    order_option = [group_by_sort_order, (options[:order] || sort_clause)].flatten.reject(&:blank?)

    base_scope.
      order(order_option).
      joins(joins_for_order_statement(order_option.join(',')))
  end

  # Returns sum of all the spent quantity
  def total_for_quantity(scope)
    map_total(scope.sum(:quantity)) {|t| t.to_f.round(2)}
  end

   # Returns sum of all the spent selling_price
  def total_for_selling_price(scope)
    map_total(scope.sum("wk_material_entries.selling_price * wk_material_entries.quantity")) {|t| t.to_f.round(2)}
  end

  def sql_for_issue_id_field(field, operator, value)
    case operator
    when "="
      "#{WkMaterialEntry.table_name}.issue_id = #{value.first.to_i}"
    when "~"
      issue = Issue.where(:id => value.first.to_i).first
      if issue && (issue_ids = issue.self_and_descendants.pluck(:id)).any?
        "#{WkMaterialEntry.table_name}.issue_id IN (#{issue_ids.join(',')})"
      else
        "1=0"
      end
    when "!*"
      "#{WkMaterialEntry.table_name}.issue_id IS NULL"
    when "*"
      "#{WkMaterialEntry.table_name}.issue_id IS NOT NULL"
    end
  end

  def sql_for_issue_fixed_version_id_field(field, operator, value)
    issue_ids = Issue.where(:fixed_version_id => value.map(&:to_i)).pluck(:id)
    case operator
    when "="
      if issue_ids.any?
        "#{WkMaterialEntry.table_name}.issue_id IN (#{issue_ids.join(',')})"
      else
        "1=0"
      end
    when "!"
      if issue_ids.any?
        "#{WkMaterialEntry.table_name}.issue_id NOT IN (#{issue_ids.join(',')})"
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
        joins << "LEFT OUTER JOIN #{IssueStatus.table_name} ON #{IssueStatus.table_name}.id = #{Issue.table_name}.status_id "+get_comp_con('issue_statuses')
      end
      if order_options.include?('trackers')
        joins << "LEFT OUTER JOIN #{Tracker.table_name} ON #{Tracker.table_name}.id = #{Issue.table_name}.tracker_id"+get_comp_con('trackers')
      end
    end

    joins.compact!
    joins.any? ? joins.join(' ') : nil
  end
end
