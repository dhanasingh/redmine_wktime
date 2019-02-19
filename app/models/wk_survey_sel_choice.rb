class WkSurveySelChoice < ActiveRecord::Base

  belongs_to :survey_choice , :class_name => 'WkSurveyChoice'
  belongs_to :user, :class_name => 'User'

  validates_presence_of :user_id, :survey_choice_id
end