module SendPatch::ContextMenusControllerPatch
  def self.included(base)
    base.class_eval do

      def time_entries
        # ============= ERPmine_patch Redmine 6.1  =====================
        @options_by_custom_field = {}
        if session[:timelog][:spent_type] === "T"
        # =======================
          @time_entries = TimeEntry.where(:id => params[:ids]).
            preload(:project => :time_entry_activities).
            preload(:user).to_a

          (render_404; return) unless @time_entries.present?
          if @time_entries.size == 1
            @time_entry = @time_entries.first
          end

          @projects = @time_entries.filter_map(&:project).uniq
          @project = @projects.first if @projects.size == 1
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

        # ============= ERPmine_patch Redmine 6.1  =====================
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
        render :layout => false
      end
    end
  end
end
