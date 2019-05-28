class WkSurveyAnsReview < ActiveRecord::Base
    belongs_to :survey_answer , :class_name => 'WkSurveyAnswer'
    belongs_to :user, :class_name => 'User'
end