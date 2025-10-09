module LoadPatch::AuthAppControllerPatch
  def self.included(base)
    base.class_eval do

      def authorize(ctrl = params[:controller], action = params[:action], global = false)
        allowed = User.current.allowed_to?({:controller => ctrl, :action => action}, @project || @projects, :global => global)
        if allowed
          true
        else
        # ============= ERPmine_patch Redmine 6.1 =====================
              wktime_helper = Object.new.extend(WktimeHelper)
              # isSupervisor = wktime_helper.isSupervisor
        # =============================
          if @project && @project.archived?
            @archived_project = @project
            render_403 :message => :notice_not_authorized_archived_project
        # ============= ERPmine_patch Redmine 6.1 =====================
          elsif ((action == 'edit' || action == 'update' || action == 'destroy') && ctrl == 'timelog' && (wktime_helper.isSupervisor && wktime_helper.canSupervisorEdit)) && wktime_helper.overrideSpentTime
            true
          elsif ((action == 'index' || action == 'report')  && ctrl == 'timelog') && wktime_helper.overrideSpentTime
            #Object.new.extend(WktimeHelper).isAccountUser || isSupervisor
            return true
        # =============================
          elsif @project && !@project.allows_to?(:controller => ctrl, :action => action)
            # Project module is disabled
            render_403
          else
            deny_access
          end
        end
      end

    end
  end
end