module LoadPatch::AllowedtoUserPatch
  def self.included(base)
    base.class_eval do

      def allowed_to?(action, context, options={}, &block)
        # ======= ERPmine_patch Redmine 6.1 ==========
        wktime_helper = Object.new.extend(WktimeHelper)
        valid_ERP_perm = wktime_helper.validateERPPermission('A_TE_PRVLG')
        isSupervisor = wktime_helper.isSupervisor
        # =============================
        if context && context.is_a?(Project)
          # ======= ERPmine_patch Redmine 6.1 ==========
          # For allow supervisor and TEadmin to view time_entry
          if ((valid_ERP_perm || isSupervisor) && action.to_s == 'view_time_entries') && wktime_helper.overrideSpentTime
            return true
          end

          if (action.to_s == 'view_time_entries') && wktime_helper.overrideSpentTime
            return (context.allows_to?(:log_time) || context.allows_to?(:edit_time_entries) || context.allows_to?(:edit_own_time_entries))
          end
          # =============================

          return false unless context.allows_to?(action)
          # Admin users are authorized for anything else
          return true if admin?

          roles = roles_for_project(context)
          return false unless roles
          roles.any? do |role|
            (context.is_public? || role.member?) &&
            role.allowed_to?(action, @oauth_scope) &&
            (block ? yield(role, self) : true)
          end
        elsif context && context.is_a?(Array)
          if context.empty?
            false
          else
          # Authorize if user is authorized on every element of the array
          context.map {|project| allowed_to?(action, project, options, &block)}.reduce(:&)
          end
        elsif context
          raise ArgumentError.new("#allowed_to? context argument must be a Project, an Array of projects or nil")
        elsif options[:global]
          # Admin users are always authorized
          return true if admin?

          # ======= ERPmine_patch Redmine 6.1 ==========
          if ((valid_ERP_perm || isSupervisor) && action.to_s == 'view_time_entries') && wktime_helper.overrideSpentTime
          return true
          end
          # User Log API
          if( action.is_a?(Hash) && action[:controller] == "wklogmaterial" && action[:action] == "index")
          return true
          end
          # =============================
          # authorize if user has at least one role that has this permission
          roles = self.roles.to_a | [builtin_role]
          roles.any? do |role|
          # ======= ERPmine_patch Redmine 6.1 ==========
          if (action.to_s == 'view_time_entries') && wktime_helper.overrideSpentTime
            (role.allowed_to?(:log_time) || role.allowed_to?(:edit_time_entries) || role.allowed_to?(:edit_own_time_entries))
          else
          # =============================
            role.allowed_to?(action, @oauth_scope) &&
            (block ? yield(role, self) : true)
          end
          end
        else
          false
        end
      end

    end
  end
end