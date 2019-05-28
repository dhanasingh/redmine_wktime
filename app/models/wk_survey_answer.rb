class WkSurveyAnswer < ActiveRecord::Base

  belongs_to :survey_choice , :class_name => 'WkSurveyChoice'
  belongs_to :survey_question , :class_name => 'WkSurveyQuestion'
  belongs_to :survey_response , :class_name => 'WkSurveyResponse'
  has_many :WkSurveyAnsReview, foreign_key: "survey_answer_id", :dependent => :destroy

  accepts_nested_attributes_for :WkSurveyAnsReview, allow_destroy: true
end