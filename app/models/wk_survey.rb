class WkSurvey < ActiveRecord::Base
    
	belongs_to :group , :class_name => 'Group'										  
    has_many :wk_survey_questions, foreign_key: "survey_id", class_name: "WkSurveyQuestion", :dependent => :destroy
    has_many :wk_survey_choices, through: :wk_survey_questions
    has_many :wk_survey_responses, foreign_key: "survey_id", :dependent => :destroy

    accepts_nested_attributes_for :wk_survey_questions, allow_destroy: true
    accepts_nested_attributes_for :wk_survey_responses, allow_destroy: true
	
    validates_presence_of :name
end