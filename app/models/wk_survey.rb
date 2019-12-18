class WkSurvey < ActiveRecord::Base
    
	belongs_to :group , :class_name => 'Group'
    belongs_to :survey_for, :polymorphic => true
    has_many :wk_survey_questions, foreign_key: "survey_id", class_name: "WkSurveyQuestion", :dependent => :destroy
    has_many :wk_survey_choices, through: :wk_survey_questions
    has_many :wk_survey_responses, foreign_key: "survey_id", :dependent => :destroy
    has_many :wk_survey_answers, through: :wk_survey_responses

    accepts_nested_attributes_for :wk_survey_questions, allow_destroy: true

    validates_presence_of :name

    scope :surveyTextQuestion, ->(survey_id){
        joins(:wk_survey_questions)
        .where("wk_surveys.id = #{survey_id} AND wk_survey_questions.question_type IN ('TB', 'MTB') AND 
            wk_survey_questions.not_in_report IS FALSE ")
        .select("wk_surveys.id, wk_surveys.name, wk_survey_questions.id AS question_id, wk_survey_questions.name AS question_name")
        .order("wk_surveys.id, wk_survey_questions.id")
    }

    scope :getTextAnswer, ->(survey_id, surveyForType){
      surveyTextQuestion(survey_id).joins(:wk_survey_answers)
      .where(" wk_survey_questions.id = wk_survey_answers.survey_question_id AND 
        wk_survey_responses.survey_for_type " + (surveyForType.blank? ? " IS NULL " : " = '#{surveyForType}'"))
      .select("wk_survey_answers.choice_text")
    }

    scope :responsedTextAnswer, ->(grpdName){
      where("wk_survey_responses.group_name = '#{grpdName}'")
      .order("wk_survey_answers.survey_response_id")
    }

    scope :currentRespTxtAnswer, -> { where("wk_survey_responses.group_name IS NULL")
      .order("wk_survey_answers.survey_response_id") 
    }

    def getGroupName
      survey_response = self.wk_survey_responses.where("wk_survey_responses.user_id =  ? ", User.current.id)
        .order("wk_survey_responses.group_date").last
      group_name = survey_response.try(:group_name)
    end
end