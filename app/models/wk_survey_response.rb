class WkSurveyResponse < ActiveRecord::Base

    belongs_to :dependent, :polymorphic => true
    belongs_to :survey, :class_name => 'WkSurvey'
    has_many :wk_survey_sel_choices, foreign_key: "survey_response_id", :dependent => :destroy
  
  end