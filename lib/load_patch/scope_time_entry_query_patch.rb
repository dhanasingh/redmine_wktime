module LoadPatch::ScopeTimeEntryQueryPatch
  def self.included(base)
    base.class_eval do

        # ============= ERPmine_patch Redmine 6.1  =====================
      def base_scope(options={})
        if options[:nonSpentTime].present?
          TimeEntry.
          joins("RIGHT JOIN issues ON time_entries.issue_id = issues.id "+get_comp_con('issues')).
          joins("INNER JOIN projects ON projects.id = time_entries.project_id OR projects.id = issues.project_id"+get_comp_con('projects')).
          joins("LEFT JOIN users ON users.id = time_entries.user_id AND users.type IN ('User', 'AnonymousUser')"+get_comp_con('users')).
          joins("LEFT JOIN enumerations ON enumerations.id = time_entries.activity_id AND enumerations.type IN ('TimeEntryActivity')"+get_comp_con('enumerations')).
          where(custom_condition).
          where(TimeEntry.visible_condition(User.current))
        else
        # ======================================
          scope = TimeEntry.visible
                     .joins(:project, :user)
                     .includes(:activity)
                     .references(:activity)
                     .left_join_issue
                     .where(statement)

          if Redmine::Database.mysql? && ActiveRecord::Base.connection.supports_optimizer_hints?
            # Provides MySQL with a hint to use a better join order and avoid slow response times
            scope.optimizer_hints('JOIN_ORDER(time_entries, projects, users)')
          else
            scope
          end
        end
      end

      def custom_condition
        if (getSupervisorCondStr || "").include?("time_entries")
          condstr = " projects.id = issues.project_id AND time_entries.id IS NULL"
          projFilter = filters && filters["project_id"]
          if filters.present? && projFilter.present?
            projFilter[:values] = User.current.memberships.map(&:project_id).map(&:to_s) if projFilter[:values] && projFilter[:values].first == 'mine'
            condstr += " AND " + sql_for_field("project_id", projFilter[:operator], projFilter[:values], "issues", "project_id")
          end
          condstr += " AND issues.project_id = #{project.id} " if project.present?
          getSupervisorCondStr.insert(getSupervisorCondStr.index("time_entries"), condstr + " ) OR ( ")
        else
          getSupervisorCondStr
        end
      end

      def results_scope(options={})
        order_option = [group_by_sort_order, (options[:order] || sort_clause)].flatten.reject(&:blank?)

        order_option << "#{TimeEntry.table_name}.id ASC"
        # ============= ERPmine_patch Redmine 6.1  =====================
        if options[:nonSpentTime].present?
          base_scope(options)
        else
        # ======================================
          base_scope.
            order(order_option).
            joins(joins_for_order_statement(order_option.join(',')))
        end
      end

      #========= ERPmine_patch Redmine 6.1 for get supervision condition string ======
      def getSupervisorCondStr
        orgCondStatement = statement
        condStatement = orgCondStatement

        wktime_helper = Object.new.extend(WktimeHelper)
        if wktime_helper.overrideSpentTime
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
            user_cond = "#{TimeEntry.table_name}.user_id IN (#{userIds})"

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
                  filters["user_id"][:values] = filterUserIds #overriding user filters to get query condition for supervisor
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
              mgrCondStatement = mgrCondStatement + "(#{TimeEntry.table_name}.project_id in (" + projectIdArr.collect{|i| i.to_s}.join(',') + "))"
              condStatement = condStatement.blank? ? condStatement : "(" + condStatement + ") OR (" + mgrCondStatement + ")"
            end
          else
            #if (!Setting.plugin_redmine_wktime['ftte_view_only_own_spent_time'].blank? &&
            #Setting.plugin_redmine_wktime['ftte_view_only_own_spent_time'].to_i == 1) &&
            if !valid_ERP_perm && !User.current.admin? && !isManager
              cond = " (#{TimeEntry.table_name}.user_id = " + User.current.id.to_s + ")"
              condStatement = condStatement.blank? ? cond : condStatement + " AND #{cond}"
            elsif isManager && !valid_ERP_perm && !User.current.admin?
              user_id = filters["user_id"][:values] if !filters["user_id"].blank?
              if !user_id.blank? && user_id.is_a?(Array) && (user_id.include?("me") || user_id.include?(User.current.id.to_s))
                condStatement = condStatement
              else
                condStatement = condStatement.blank? ? condStatement : "(" + condStatement + ") AND (#{TimeEntry.table_name}.project_id in (" + projectIdArr.collect{|i| i.to_s}.join(',') + "))"
              end
            end
          end
        end
        condStatement
      end
      # =============================

    end
  end
end