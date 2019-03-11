class WkSurveyChoice < ActiveRecord::Base

  has_many :wk_survey_sel_choices, foreign_key: "survey_choice_id", class_name: "WkSurveySelChoice", :dependent => :destroy
  belongs_to :survey_question , :class_name => 'WkSurveyQuestion'

  validates_presence_of :name

end