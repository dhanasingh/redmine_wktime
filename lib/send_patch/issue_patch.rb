module SendPatch::IssuePatch
  def self.included(base)
    base.class_eval do

      has_one :wk_issue, :dependent => :destroy, :class_name => 'WkIssue'
      has_many :assignees, :dependent => :destroy, :class_name => 'WkIssueAssignee'
      has_many :expense_entries, :dependent => :destroy, :class_name => 'WkExpenseEntry'
      accepts_nested_attributes_for :assignees
      accepts_nested_attributes_for :wk_issue

      def erpmineissues
        self.wk_issue ||= WkIssue.new(:issue => self, :project => self.project)
      end

    end
  end
end