class WkStatus < ActiveRecord::Base
    belongs_to :spent_for, :polymorphic => true
    belongs_to :status_for, :class_name => 'WkSurveyResponse'

    validates_presence_of :status_date, :status
end