module Wkdashboard
  module Graph002ExpenseForIssues
    include WktimeHelper

    def chart_data(param={})
      data = {
        graphName: l(:label_expense_for_issues), chart_type: "doughnut", xTitle: l(:field_hours), yTitle: l(:label_day_plural),
        legentTitle1: l(:label_total_expense_of_issues)
      }
      entries = getExpenses(param)
      entries = entries.group(:issue_id).select("issue_id, sum(amount) as total_amount")
      entries = entries.where(project_id: param[:project_id]) if param[:project_id].present?
      expenses = entries.map{|c| ["#"+c.issue.id.to_s+": "+c.issue.subject, c.total_amount.round(2)]}.to_h
      data[:fields] = expenses.keys
      data[:data1] = expenses.values
      return data
    end

    def get_detail_report(param={})
      entries = getExpenses(param).order("spent_on DESC")
      header = {issue: l(:field_issue), user: l(:field_user), date: l(:label_spent_on), amount: l(:field_amount)}
      data = entries.map{|e| { issue: e&.issue&.to_s, user: e&.user&.name, spent_on: e&.spent_on.to_date, amount: (e.currency || "").to_s+ " " +(e.amount.round(2) || "").to_s }}
      return {header: header, data: data}
    end

    private

    def getExpenses(param={})
      WkExpenseEntry.where("issue_id IS NOT NULL AND spent_on BETWEEN ? AND ?", param[:from], param[:to])
    end
  end
end