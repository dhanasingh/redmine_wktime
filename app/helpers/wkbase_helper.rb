module WkbaseHelper
	include ActionView::Helpers::TagHelper

  def getIssueList(issue, params=nil)
    issue = issue.like(params[:q]) if params.present?
    issues = (+'').html_safe
    issue.each do |entry|
      issues << content_tag('span', entry.subject, class: "issue_select", id: entry.id)
    end
    issues
  end
end
