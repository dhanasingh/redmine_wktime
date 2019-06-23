class WkProject < ActiveRecord::Base

    include Redmine::SafeAttributes
    belongs_to :project
    safe_attributes 'is_issueSurvey_allowed', 'project_id', 'billing_rate', 'billing_currency', 'is_billable', 'profit_overhead_percentage'
end