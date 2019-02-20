class WkSelSurvey < ActiveRecord::Base

    belongs_to :parent, :polymorphic => true
    belongs_to :survey, :class_name => 'WkSurvey'
    has_many :wk_survey_sel_choices, foreign_key: "sel_survey_id", :dependent => :destroy
  
  end