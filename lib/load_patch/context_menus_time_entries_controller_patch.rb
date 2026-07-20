module LoadPatch::ContextMenusTimeEntriesControllerPatch
  def self.included(base)
    base.class_eval do

      # In Redmine 7.0 the monolithic ContextMenusController#time_entries action
      # became ContextMenus::TimeEntriesController#index. For expense (E) and
      # material (M) entries the ids don't refer to TimeEntry records, so skip
      # the default find_time_entries lookup (which would render_404) and let
      # #index load the proper records.
      def find_time_entries
      # ============= ERPmine_patch Redmine 7.0 =====================
        return if session[:timelog] && session[:timelog][:spent_type] != "T"
      # =======================
        @time_entries = TimeEntry.find_with_preloads(params[:ids])

        if @time_entries.blank? || !@time_entries.all?(&:visible?)
          render_404
          return
        end

        if @time_entries.size == 1
          @time_entry = @time_entries.first
        end

        find_project_from_items(@time_entries)
      end

      def index
        @options_by_custom_field = {}
        if session[:timelog].nil? || session[:timelog][:spent_type] === "T"
          @activities = @projects.map(&:activities).reduce(:&)

          edit_allowed = @time_entries.all? {|t| t.editable_by?(User.current)}
          @can = {:edit => edit_allowed, :delete => edit_allowed}
          @back = back_url

          @options_by_custom_field = {}
          if @can[:edit]
            custom_fields = @time_entries.map(&:editable_custom_fields).reduce(:&).reject(&:multiple?).select {|field| field.format.bulk_edit_supported}
            custom_fields.each do |field|
              values = field.possible_values_options(@projects)
              if values.present?
                @options_by_custom_field[field] = values
              end
            end
          end

        # ============= ERPmine_patch Redmine 7.0 =====================
        elsif session[:timelog][:spent_type] === "E"
          @time_entries = WkExpenseEntry.where(id: params[:ids]).to_a
          @can = {:edit => true, :delete => true}
        else
          @time_entries = WkMaterialEntry.where(id: params[:ids]).to_a
          @can = {:edit => true, :delete => true}
        end
        (render_404; return) unless @time_entries.present?
        if @time_entries.size == 1
          @time_entry = @time_entries.first
        end
        # =======================

        render_context_menu 'time_entries'
      end
    end
  end
end
