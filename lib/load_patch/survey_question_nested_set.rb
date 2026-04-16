module LoadPatch
  module SurveyQuestionNestedSet
    def self.included(base)
      base.class_eval do
        belongs_to :parent, :class_name => self.name, :optional => true

        before_create :add_to_nested_set
        before_update :move_in_nested_set, :if => lambda {|q| q.parent_id_changed? || q.sort_order_changed?}
        before_destroy :update_children # standard redmine behavior
      end
      base.extend ClassMethods
      base.send :include, Redmine::NestedSet::Traversing
    end

    private

    def update_children
      self.class.where(:parent_id => id).update_all(:parent_id => nil)
      self.class.rebuild_tree!(survey_id)
    end

    def target_lft
      # Order siblings by sort_order instead of name to preserve manual UI drag-and-drop
      siblings_rgt = self.class.where(:survey_id => survey_id, :parent_id => parent_id)
                         .where("sort_order < ?", sort_order.to_i).maximum(:rgt)
      if siblings_rgt
        siblings_rgt + 1
      elsif parent_id
        parent_lft = self.class.where(:id => parent_id).pluck(:lft).first
        raise "question id=#{id} with parent_id=#{parent_id}: parent missing or without 'lft' value" unless parent_lft
        parent_lft + 1
      else
        # For root questions, find the highest right value of previous root questions
        # We order by sort_order. If multiple have the same sort_order, we use ID as fallback.
        prev_root = self.class.where(:survey_id => survey_id, :parent_id => nil)
                                  .where("sort_order < ?", sort_order.to_i)
                                  .order(rgt: :desc).first
        if prev_root
          prev_root.rgt + 1
        else
          1
        end
      end
    end

    def add_to_nested_set(lock=true)
      lock_nested_set if lock
      self.lft = target_lft
      self.rgt = lft + 1
      self.class.where(:survey_id => survey_id).where("lft >= ? OR rgt >= ?", lft, lft).update_all([
        "lft = CASE WHEN lft >= :lft THEN lft + 2 ELSE lft END, " +
        "rgt = CASE WHEN rgt >= :lft THEN rgt + 2 ELSE rgt END",
        {:lft => lft}
      ])
    end

    def move_in_nested_set
      lock_nested_set
      reload_nested_set_values
      a = lft
      b = rgt
      c = target_lft
      unless c == a
        if c > a
          # Moving to the right
          d = c - (b - a + 1)
          scope = self.class.where(:survey_id => survey_id).where(["lft BETWEEN :a AND :c - 1 OR rgt BETWEEN :a AND :c - 1", {:a => a, :c => c}])
          scope.update_all([
            "lft = CASE WHEN lft BETWEEN :a AND :b THEN lft + (:d - :a) WHEN lft BETWEEN :b + 1 AND :c - 1 THEN lft - (:b - :a + 1) ELSE lft END, " +
            "rgt = CASE WHEN rgt BETWEEN :a AND :b THEN rgt + (:d - :a) WHEN rgt BETWEEN :b + 1 AND :c - 1 THEN rgt - (:b - :a + 1) ELSE rgt END",
            {:a => a, :b => b, :c => c, :d => d}
          ])
        elsif c < a
          # Moving to the left
          scope = self.class.where(:survey_id => survey_id).where("lft BETWEEN :c AND :b OR rgt BETWEEN :c AND :b", {:a => a, :b => b, :c => c})
          scope.update_all([
            "lft = CASE WHEN lft BETWEEN :a AND :b THEN lft - (:a - :c) WHEN lft BETWEEN :c AND :a - 1 THEN lft + (:b - :a + 1) ELSE lft END, " +
            "rgt = CASE WHEN rgt BETWEEN :a AND :b THEN rgt - (:a - :c) WHEN rgt BETWEEN :c AND :a - 1 THEN rgt + (:b - :a + 1) ELSE rgt END",
            {:a => a, :b => b, :c => c, :d => d}
          ])
        end
        reload_nested_set_values
      end
    end
    
    def destroy_children
      unless @without_nested_set_update
        lock_nested_set
        reload_nested_set_values
      end
      children.each {|c| c.send :destroy_without_nested_set_update}
      unless @without_nested_set_update
        self.class.where(:survey_id => survey_id).where("lft > ? OR rgt > ?", lft, lft).update_all([
          "lft = CASE WHEN lft > :lft THEN lft - :shift ELSE lft END, " +
          "rgt = CASE WHEN rgt > :lft THEN rgt - :shift ELSE rgt END",
          {:lft => lft, :shift => rgt - lft + 1}
        ])
      end
    end

    def destroy_without_nested_set_update
      @without_nested_set_update = true
      destroy
    end

    def reload_nested_set_values
      self.lft, self.rgt = self.class.where(:id => id).pluck(:lft, :rgt).first
    end

    def save_nested_set_values
      self.class.where(:id => id).update_all(:lft => lft, :rgt => rgt)
    end

    def move_possible?(question)
      new_record? || !is_or_is_ancestor_of?(question)
    end

    def lock_nested_set
      lock = true
      if self.class.connection.adapter_name =~ /sqlserver/i
        lock = "WITH (ROWLOCK HOLDLOCK UPDLOCK)"
      end
      self.class.order(:id).lock(lock).ids
    end

    def nested_set_scope
      self.class.where(:survey_id => survey_id).order(:lft)
    end

    def same_nested_set_scope?(question)
      survey_id == question.survey_id
    end

    module ClassMethods
      def rebuild_tree!(survey_id = nil)
        transaction do
          reorder(:id).lock.ids
          if survey_id.present?
            where(survey_id: survey_id).update_all(lft: nil, rgt: nil)
          else
            update_all(lft: nil, rgt: nil)
          end
          rebuild_nodes(survey_id)
        end
      end

      private

      def rebuild_nodes(survey_id = nil, parent_id = nil)
        if survey_id.nil?
          # Rebuild for all surveys
          WkSurvey.select(:id).each do |s|
            rebuild_nodes(s.id, nil)
          end
        else
          nodes = where(:survey_id => survey_id, :parent_id => parent_id).where(:rgt => nil, :lft => nil).reorder(:sort_order)

          nodes.each do |node|
            node.send :add_to_nested_set, false
            node.send :save_nested_set_values
            rebuild_nodes(survey_id, node.id)
          end
        end
      end
    end
  end
end
