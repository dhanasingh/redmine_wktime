class WkSurveyReview < ActiveRecord::Base
    belongs_to :survey_response, :class_name => 'WkSurveyResponse'
    belongs_to :survey_question, :class_name => 'WkSurveyQuestion'
    belongs_to :user, :class_name => 'User'
end