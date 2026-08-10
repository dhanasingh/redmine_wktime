# Per-request store for location-visibility. Rails auto-resets all
# ActiveSupport::CurrentAttributes subclasses at the end of each request, so
# nothing leaks across requests (the request_store gem is not installed).
class WkCurrent < ActiveSupport::CurrentAttributes
  # default_scope for index/edit/show/associations.
  attribute :location_scope_active

  # { user_id => accessible_location_ids } memo so resolution runs once/request.
  attribute :location_ids_cache

  # { user_id => permitted final (deepest-leaf) location ids } memo — edit forms
  # can render one dropdown per row, so the tree walk must run once per request.
  attribute :location_final_ids_cache
end
