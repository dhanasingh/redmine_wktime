class WkSurveyChoice < ActiveRecord::Base

  has_many :wk_survey_answers, foreign_key: "survey_choice_id", class_name: "WkSurveyAnswer", :dependent => :destroy
  belongs_to :survey_question , :class_name => 'WkSurveyQuestion'

end