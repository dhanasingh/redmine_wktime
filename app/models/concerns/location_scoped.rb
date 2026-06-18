# Location default_scope. Filters records to the current user's permitted location
# subtree on ALL controller actions (WkCurrent.location_scope_active is set by
# WkbaseController for every action). For unrestricted/ADM_ERP users,
# accessible_location_ids returns nil and the scope is a no-op.
# System methods that must bypass the filter (e.g. attendance/payroll calculations)
# should call .unscoped explicitly.
# Include in models with a direct `location_id` column.
module LocationScoped
  extend ActiveSupport::Concern

  included do
    default_scope {
      if WkCurrent.location_scope_active && (ids = WkLocation.accessible_location_ids)
        where(location_id: ids)
      else
        all
      end
    }
  end
end
