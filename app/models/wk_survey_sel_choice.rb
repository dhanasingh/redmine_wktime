class WkSurveySelChoice < ActiveRecord::Base

  belongs_to :survey_choice , :class_name => 'WkSurveyChoice'
  belongs_to :survey_question , :class_name => 'WkSurveyQuestion'
  belongs_to :survey_response , :class_name => 'WkSurveyResponse'

end