class WkSurveyResponse < ActiveRecord::Base

    belongs_to :survey, :class_name => 'WkSurvey'
    belongs_to :user, :class_name => 'User'
    has_many :wk_survey_answers, foreign_key: "survey_response_id", :dependent => :destroy

    accepts_nested_attributes_for :wk_survey_answers, allow_destroy: true
	
	validates_presence_of :user_id, :survey_id
  end