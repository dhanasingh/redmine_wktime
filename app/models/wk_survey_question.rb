class WkSurveyQuestion < ActiveRecord::Base

    belongs_to :survey , :class_name => 'WkSurvey'
    has_many :wk_survey_choices, foreign_key: "survey_question_id", class_name: "WkSurveyChoice", :dependent => :destroy
  
    accepts_nested_attributes_for :wk_survey_choices
    validates_presence_of :name
  
  end