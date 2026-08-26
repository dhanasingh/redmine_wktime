# ERPmine - ERP for service industry
# Copyright (C) 2011-  Adhi software pvt ltd
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

class WkLocation < ApplicationRecord

  include NestedSet::LocationNestedSet

  belongs_to :address, :class_name => 'WkAddress', :dependent => :destroy
  has_many :inventory_items, foreign_key: "location_id", class_name: "WkInventoryItem", :dependent => :restrict_with_error
  belongs_to :location_type, :class_name => 'WkCrmEnumeration'
  has_many :contacts, foreign_key: "location_id", class_name: "WkCrmContact", :dependent => :restrict_with_error
  has_many :acounts, foreign_key: "location_id", class_name: "WkAccount", :dependent => :restrict_with_error
  before_save :check_default, :check_main
  acts_as_attachable :view_permission => :view_files,
                    :edit_permission => :manage_files,
                    :delete_permission => :manage_files

  validates_presence_of :name

  scope :getMainLogo, -> { getMainLocation() }
  scope :getLogoDD, ->(locationID) { joins(:attachments).where("attachments.content_type LIKE 'image/%' AND wk_locations.id = ?", locationID).select('attachments.id, attachments.filename') }

  def self.default_id
    WkLocation.where(:is_default => 'true').first&.id
  end

  # Location id a NEW record should default to for `user`, respecting the
  # permitted-location scope. Unrestricted users (admins / no perm_location) get
  # the global is_default location. A user restricted to a permitted subtree gets
  # the global default when it falls inside that subtree, otherwise their own
  # permitted location - so create flows (e.g. the mobile API, which pre-selects
  # defaultLocation) never file records under a location outside the user's scope.
  def self.default_id_for(user = User.current)
    ids = accessible_location_ids(user)
    default = default_id
    return default if ids.nil? || (default && ids.include?(default))
    pl = WkUser.find_by(user_id: user&.id)&.perm_location
    (pl.present? && ids.include?(pl)) ? pl : (ids.first || default)
  end

  # Sanitises a user-supplied location_id on the WRITE path: returns it unchanged
  # when the user may file a record there (inside their permitted subtree, or
  # unrestricted), otherwise falls back to their permitted default. Blank / "0"
  # (no location) passes through untouched. This makes the permission model that
  # the read default_scope enforces also hold on writes - a crafted web/mobile-API
  # request can no longer store a record under a location outside the user's scope.
  def self.permit_or_default(location_id, user = User.current)
    return location_id if location_id.blank? || location_id.to_s == "0"
    ids = accessible_location_ids(user)
    return location_id if ids.nil? || ids.include?(location_id.to_i)
    default_id_for(user)
  end

  # Boolean sibling of permit_or_default: true when `user` may file a record at
  # `location_id` (it is inside their permitted subtree, or they are unrestricted).
  # Used where there is no sensible value to fall back to and an out-of-scope choice
  # must be rejected rather than silently redirected - e.g. a resident move-in
  # references an apartment by id, which can't be "clamped" to another apartment.
  # A blank location is only allowed for unrestricted users.
  def self.permitted?(location_id, user = User.current)
    ids = accessible_location_ids(user)
    ids.nil? || (location_id.present? && ids.include?(location_id.to_i))
  end

  # Single source of truth for per-user location visibility. Model-safe (no
  # controller-only call_hook) so it can be used from scopes and raw-SQL builders.
  # Memoized per request (WkCurrent, auto-reset each request) since the gated
  # default_scope calls it on every query of the scoped models during a list.
  #   nil  => unrestricted (ADM_ERP permission, or blank/0 perm_location => old flow)
  #   []   => perm_location is set but points to a missing location
  #   [..] => the permitted location subtree ids
  def self.accessible_location_ids(user = User.current)
    cache = (WkCurrent.location_ids_cache ||= {})
    key = user&.id
    return cache[key] if cache.key?(key)
    cache[key] = compute_accessible_location_ids(user)
  end

  def self.compute_accessible_location_ids(user)
    return nil unless user&.logged?
    return nil if WkPermission.joins(:grpPermission)
                    .where(wk_group_permissions: { group_id: user.groups.pluck(:id) })
                    .where(short_name: 'ADM_ERP').exists?
    # perm_location is the sole driver of scoping. Blank/0 => unrestricted (the
    # original pre-permission flow); location_id is NOT used for access scoping.
    pl = WkUser.find_by(user_id: user.id)&.perm_location
    return nil if pl.blank? || pl == 0
    root = WkLocation.unscoped.find_by(id: pl)
    root ? root.self_and_descendants.pluck(:id) : []
  end
  private_class_method :compute_accessible_location_ids

  # Picked-location filter helper: the given location id plus all its descendants
  # (nested set). Lets a parent selection (e.g. a zone) match records stored at its
  # child locations. Falls back to [id] if the location is missing, so behaviour
  # degrades to an exact match. Returns integers, safe to interpolate in SQL.
  def self.subtree_ids(location_id)
    return [] if location_id.blank?
    loc = unscoped.find_by(id: location_id)
    loc ? loc.self_and_descendants.pluck(:id) : [location_id.to_i]
  end

  # Effective location-id restriction for report builders: the intersection of the
  # picked location's subtree (when one is selected) with the user's accessible
  # scope. Single source of truth so every report filters identically.
  #   nil  => no restriction at all (admin/unrestricted AND no location picked) =>
  #           caller should add no location condition.
  #   [..] => the allowed location ids (use `ids.presence || [-1]` so an empty
  #           intersection matches nothing rather than producing invalid SQL).
  def self.report_location_ids(location_id, user = User.current)
    acc = accessible_location_ids(user)
    sel = (location_id.present? && location_id.to_s != "0") ? subtree_ids(location_id) : nil
    [acc, sel].compact.reduce(:&)
  end

  # Deepest-leaf locations PER top-level zone within `scope`: for each top-level
  # root (the depth-0 ancestor within scope), the leaves (no children in scope) at
  # that root's MAXIMUM leaf depth. So an uneven branch (e.g. Madurai -> Melur)
  # collapses to its deepest leaf (Melur), while shallower-but-sibling zones keep
  # their own deepest leaves. Computed over the given scope, so it works at any
  # permission level (a user permitted only one leaf still gets that leaf). Used by
  # edit-form location dropdowns.
  def self.final_location_ids(scope = all)
    ordered, depths, ancestors = tree_ordered_by_name(scope)
    has_child = ordered.map(&:parent_id).compact.to_set
    root_of = ->(l) { (ancestors[l.id] && ancestors[l.id].first) || l.id }
    max_depth = Hash.new(-1)
    ordered.each do |l|
      next if has_child.include?(l.id)               # leaves only
      r = root_of.call(l); d = depths[l.id] || 0
      max_depth[r] = d if d > max_depth[r]
    end
    ordered.select { |l|
      !has_child.include?(l.id) && (depths[l.id] || 0) == max_depth[root_of.call(l)]
    }.map(&:id)
  end

  # Final-leaf ids within the current user's PERMITTED scope, memoized per request
  # (row-repeated edit forms render one location dropdown per row — without the
  # memo each render reloads the location table and walks the tree).
  def self.permitted_final_location_ids(user = User.current)
    cache = (WkCurrent.location_final_ids_cache ||= {})
    key = user&.id
    return cache[key] if cache.key?(key)
    ids = accessible_location_ids(user)
    cache[key] = final_location_ids(ids ? where(id: ids) : all)
  end

  # Applies the contact/account location condition to a relation already joined
  # to wk_crm_contacts + wk_accounts (Residents, Incidents, Account-Projects,
  # Evaluations, ...). Single home for the OR-condition so every join-based page
  # filters identically. nil ids => unrestricted => relation unchanged;
  # [] => matches nothing.
  def self.filter_by_contact_account_location(relation, ids)
    return relation if ids.nil?
    relation.where(
      "wk_crm_contacts.location_id IN (:ids) OR wk_accounts.location_id IN (:ids)",
      ids: ids.presence || [-1])
  end

  # SQL condition string for raw-SQL / join queries (e.g. find_by_sql), or nil
  # when the current user is unrestricted. ids come from pluck so are integers.
  def self.accessible_location_sql(table_alias, column = 'location_id')
    ids = accessible_location_ids
    return nil if ids.nil?
    "#{table_alias}.#{column} IN (#{(ids.presence || [-1]).join(',')})"
  end

  # SQL condition (or nil when unrestricted) that scopes a CRM record's polymorphic
  # parent (parent_type / parent_id columns on `table_alias`) to the current user's
  # accessible contact/account locations. Handles direct WkCrmContact / WkAccount
  # parents and one level of WkLead -> contact and WkOpportunity -> (contact|account).
  # Used by the CRM dashboard activity/opportunity graphs.
  def self.accessible_parent_sql(table_alias)
    ids = accessible_location_ids
    return nil if ids.nil?
    cids = (WkCrmContact.unscoped.where(location_id: ids).pluck(:id).presence || [-1]).join(',')
    aids = (WkAccount.unscoped.where(location_id: ids).pluck(:id).presence || [-1]).join(',')
    t = table_alias
    "(" \
      "(#{t}.parent_type = 'WkCrmContact' AND #{t}.parent_id IN (#{cids})) OR " \
      "(#{t}.parent_type = 'WkAccount' AND #{t}.parent_id IN (#{aids})) OR " \
      "(#{t}.parent_type = 'WkLead' AND #{t}.parent_id IN (SELECT id FROM wk_leads WHERE contact_id IN (#{cids}))) OR " \
      "(#{t}.parent_type = 'WkOpportunity' AND #{t}.parent_id IN (SELECT id FROM wk_opportunities WHERE " \
        "(parent_type = 'WkCrmContact' AND parent_id IN (#{cids})) OR (parent_type = 'WkAccount' AND parent_id IN (#{aids}))))" \
    ")"
  end

  # Returns [ordered_array, depths_hash, ancestor_ids_hash] for the given
  # scope, walking the tree depth-first with siblings sorted alphabetically.
  # Rows whose parent is missing from the scope are promoted to roots.
  def self.tree_ordered_by_name(scope = all)
    all_rows = scope.to_a
    visible = all_rows.index_by(&:id)
    children_of = all_rows.group_by(&:parent_id)
    children_of.each_value { |arr| arr.sort_by! { |l| l.name.to_s.downcase } }

    ordered = []
    depths = {}
    ancestor_ids = {}

    walk = lambda do |node, stack|
      depths[node.id] = stack.size
      ancestor_ids[node.id] = stack.dup
      ordered << node
      (children_of[node.id] || []).each { |c| walk.call(c, stack + [node.id]) }
    end

    roots = all_rows.reject { |l| l.parent_id && visible.key?(l.parent_id) }
    roots.sort_by! { |l| l.name.to_s.downcase }
    roots.each { |r| walk.call(r, []) }

    [ordered, depths, ancestor_ids]
  end

  def check_default
    if is_default? && is_default_changed?
      WkLocation.update_all({:is_default => false})
    end
  end

  def check_main
    if is_main? && is_main_changed?
      WkLocation.update_all({:is_main => false})
    end
  end

  def self.getMainLocation
    entry = WkLocation.where(is_main: true)
    attachment_id = entry.first && entry.first.attachment_id
    entry = Attachment.where(id: attachment_id).first
    (entry || {})
  end
end
