require 'redmine/nested_set/issue_nested_set'

module NestedSet
  # Tree behaviour for WkLocation. Reuses Redmine's IssueNestedSet for the
  # nested-set algorithm and overrides only what differs for locations.
  module LocationNestedSet
    def self.included(base)
      base.class_eval do
        include Redmine::NestedSet::IssueNestedSet

        validate :validate_parent, if: :parent_id_changed?

        # Prepended so these win over IssueNestedSet in method lookup.
        prepend Overrides
      end
    end

    module Overrides
      # Replaces IssueNestedSet's lock_nested_set — its MySQL branch hardcodes
      # Issue.with_advisory_lock! (wrong table for locations). Uses a portable
      # SELECT FOR UPDATE on all rows in the affected tree(s) so concurrent
      # admin edits serialise instead of corrupting lft/rgt.
      def lock_nested_set
        self.class.transaction do
          sets_to_lock = [id, parent_id].compact
          if sets_to_lock.any?
            self.class.where(
              "root_id IN (SELECT root_id FROM #{self.class.table_name} WHERE id IN (?))",
              sets_to_lock
            ).lock.ids
          end
          yield
        end
      end
    end

    def validate_parent
      return if parent_id.blank?
      p = self.class.find_by(id: parent_id)
      errors.add(:parent_id, :invalid) if p.nil? || !move_possible?(p)
    end

    def allowed_parents
      self.class.where.not(id: self_and_descendants.pluck(:id))
    end
  end
end
