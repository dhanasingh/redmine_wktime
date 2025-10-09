module LoadPatch::TimeReportPatch
  module Redmine::Helpers
    class TimeReport

      attr_reader :criteria, :columns, :hours, :total_hours, :periods

      # ============= ERPmine_patch Redmine 6.1  =====================
      def initialize(project, criteria, columns, time_entry_scope, options={})
        @options = options
        # ======================================
        @project = project

        # ============= ERPmine_patch Redmine 6.1  =====================
        @scope = time_entry_scope
        # ======================================
        @criteria = criteria || []
        @criteria = @criteria.select{|criteria| available_criteria.has_key? criteria}
        @criteria.uniq!
        @criteria = @criteria[0,3]

        @columns = (columns && %w(year month week day).include?(columns)) ? columns : 'month'

        run
      end

      private

      def run
        unless @criteria.empty?
          time_columns = %w(tyear tmonth tweek spent_on)
          @hours = []
          # ============= ERPmine_patch Redmine 6.1  =====================
          scopeArr = @scope.attribute_names
          if scopeArr.include? "selling_price"
          # ======================================

            @scope.includes(:activity).
                reorder(nil).
                group(@criteria.collect{|criteria| @available_criteria[criteria][:sql]} + time_columns).
                joins(@criteria.filter_map{|criteria| @available_criteria[criteria][:joins]}).
            # ============= ERPmine_patch Redmine 6.1  =====================
            sum("wk_material_entries.selling_price * wk_material_entries.quantity").each do |hash, selling_price|
              h = {'hours' => selling_price}
              (@criteria + time_columns).each_with_index do |name, i|
                h[name] = hash[i]
              end
              @hours << h
            end
          elsif scopeArr.include? "amount"
            @scope.includes(:activity).
              reorder(nil).
              group(@criteria.collect{|criteria| @available_criteria[criteria][:sql]} + time_columns).
              joins(@criteria.filter_map{|criteria| @available_criteria[criteria][:joins]}).
              sum(:amount).each do |hash, amount|
                h = {'hours' => amount}
                (@criteria + time_columns).each_with_index do |name, i|
                  h[name] = hash[i]
                end
                @hours << h
              end
          else
            @scope.includes(:activity).
              reorder(nil).
              group(@criteria.collect{|criteria| @available_criteria[criteria][:sql]} + time_columns).
              joins(@criteria.filter_map{|criteria| @available_criteria[criteria][:joins]}).
            # ==============================
              sum(:hours).each do |hash, hours|
                h = {'hours' => hours}
                (@criteria + time_columns).each_with_index do |name, i|
                  h[name] = hash[i]
                end
                @hours << h
              end
          # ============= ERPmine_patch Redmine 6.1  =====================
          end
          # ==============================

          @hours.each do |row|
            case @columns
            when 'year'
              row['year'] = row['tyear']
            when 'month'
              row['month'] = "#{row['tyear']}-#{row['tmonth']}"
            when 'week'
              # ============= ERPmine_patch Redmine 6.1  =====================
              row['week'] = "#{row['spent_on'].cwyear}-#{row['tweek']}" if row['spent_on'].present?
              # ==============================
            when 'day'
              row['day'] = "#{row['spent_on']}"
            end
          end
          # ============= ERPmine_patch Redmine 6.1  =====================
          min = @hours.pluck('spent_on').min
          @from = min ? min.to_date : User.current.today

          max = @hours.pluck('spent_on').max
          # ==============================
          @to = max ? max.to_date : User.current.today

          @total_hours = @hours.inject(0) {|s,k| s = s + k['hours'].to_f}

          @periods = []
          # Date#at_beginning_of_ not supported in Rails 1.2.x
          date_from = @from.to_time
          # 100 columns max
          while date_from <= @to.to_time && @periods.length < 100
            case @columns
            when 'year'
              @periods << "#{date_from.year}"
              date_from = (date_from + 1.year).at_beginning_of_year
            when 'month'
              @periods << "#{date_from.year}-#{date_from.month}"
              date_from = (date_from + 1.month).at_beginning_of_month
            when 'week'
              @periods << "#{date_from.to_date.cwyear}-#{date_from.to_date.cweek}"
              date_from = (date_from + 7.day).at_beginning_of_week
            when 'day'
              @periods << "#{date_from.to_date}"
              date_from = date_from + 1.day
            end
          end
        end
      end

      def load_available_criteria
        # ============= ERPmine_patch Redmine 6.1  =====================
        scopeArr = @scope.attribute_names
        if scopeArr.include? "selling_price"
          model =  WkMaterialEntry
        elsif scopeArr.include? "amount"
          model = WkExpenseEntry
        else
          model =  TimeEntry
        end
        # ==================================
        @available_criteria = {
        # ============= ERPmine_patch Redmine 6.1  =====================
          'project' => {:sql => @options[:nonSpentTime].present? ? "coalesce(time_entries.project_id, issues.project_id)" : "#{model.table_name}.project_id",
        # ==================================
                      :klass => Project,
                      :label => :label_project},
          'status' => {:sql => "#{Issue.table_name}.status_id",
                      :klass => IssueStatus,
                      :label => :field_status},
          'version' => {:sql => "#{Issue.table_name}.fixed_version_id",
                      :klass => ::Version,
                      :label => :label_version},
          'category' => {:sql => "#{Issue.table_name}.category_id",
                        :klass => IssueCategory,
                        :label => :field_category},
          # ============= ERPmine_patch Redmine 6.1  =====================
          'user' => {:sql => @options[:nonSpentTime].present? ? "coalesce(time_entries.user_id, issues.assigned_to_id)" : "#{model.table_name}.user_id",
          # ==================================
                      :klass => User,
                      :label => :label_user},
          'tracker' => {:sql => "#{Issue.table_name}.tracker_id",
                      :klass => Tracker,
                      :label => :label_tracker},
          'activity' => {:sql => "COALESCE(#{TimeEntryActivity.table_name}.parent_id, #{TimeEntryActivity.table_name}.id)",
                        :klass => TimeEntryActivity,
          # ============= ERPmine_patch Redmine 6.1  =====================
                        :label => :label_activity},
          'issue' => {:sql => @options[:nonSpentTime].present? ? "coalesce(time_entries.issue_id, issues.id)" :  "#{model.table_name}.issue_id",
          # ==================================
                      :klass => Issue,
                      :label => :label_issue}
        }

        # ============= ERPmine_patch Redmine 6.1  =====================
        if scopeArr.include? "selling_price"
          hashval = {
                'Product Item' => {:sql => "#{WkMaterialEntry.table_name}.inventory_item_id",
                            :klass => WkInventoryItem,
                            :label => :label_product_items}
                }
          @available_criteria.merge!(hashval)
        end
        # ==================================
        # Add time entry custom fields
        custom_fields = TimeEntryCustomField.visible
        # Add project custom fields
        custom_fields += ProjectCustomField.visible
        # Add issue custom fields
        custom_fields += @project.nil? ? IssueCustomField.visible.for_all : @project.all_issue_custom_fields.visible
        # Add time entry activity custom fields
        custom_fields += TimeEntryActivityCustomField.visible

        # Add list and boolean custom fields as available criteria
        custom_fields.select {|cf| %w(list bool).include?(cf.field_format) && !cf.multiple?}.each do |cf|
          @available_criteria["cf_#{cf.id}"] = {:sql => cf.group_statement,
                                                  :joins => cf.join_for_order_statement,
                                                  :format => cf.field_format,
                                                  :custom_field => cf,
                                                  :label => cf.name}
        end

        @available_criteria
      end
    end

  end
end