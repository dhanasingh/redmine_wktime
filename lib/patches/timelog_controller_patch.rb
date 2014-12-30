require_dependency 'timelog_controller'

module  Patches
  module TimelogControllerPatch
    def self.included(base)
      base.extend(ClassMethods)

      base.send(:include, InstanceMethods)
      base.class_eval do

        before_filter :test_wktime, :only=>[:create]

      end
    end
  end
  module ClassMethods
  end

  module InstanceMethods
    def test_wktime
      @time_entry ||= TimeEntry.new(:project => @project, :issue => @issue, :user => User.current, :spent_on => User.current.today)
      @time_entry.safe_attributes = params[:time_entry]
      if @time_entry.project && !User.current.allowed_to?(:log_time, @time_entry.project)
        render_403
        return
      end
      if !@time_entry.hours.blank? && !@time_entry.activity_id.blank?
        wktime_helper = Object.new.extend(WktimeHelper)
        status= wktime_helper.getTimeEntryStatus(@time_entry.spent_on, @time_entry.user_id)
        if !status.blank? && ('a' == status || 's' == status)
          render_error({:message=>:label_warning_wktime_time_entry, :status=> 403})
          return false
        end
      end
    end
  end
end