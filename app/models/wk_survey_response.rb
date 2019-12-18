class WkSurveyResponse < ActiveRecord::Base

    belongs_to :survey, :class_name => 'WkSurvey'
    belongs_to :user, :class_name => 'User'
    has_many :wk_survey_answers, foreign_key: "survey_response_id", :dependent => :destroy
    has_many :wk_statuses, foreign_key: "status_for_id", :dependent => :destroy
    has_many :wk_survey_reviews, foreign_key: "survey_response_id", :dependent => :destroy

    accepts_nested_attributes_for :wk_survey_answers, allow_destroy: true
    accepts_nested_attributes_for :wk_statuses, allow_destroy: true
    accepts_nested_attributes_for :wk_survey_reviews, allow_destroy: true

    validates_presence_of :user_id, :survey_id

    scope :getClosedResp, ->(surveyID){
        select("COUNT(id), group_name, survey_id ")
        .group("survey_id, group_name, group_date")
        .where("survey_id = #{surveyID}")
        .order("group_date")
    }

    scope :updateRespGrp, ->(surveyID, group_date, grp_name){
        where("survey_id = #{surveyID} AND group_date IS NULL")
        .update_all(group_date: group_date.to_datetime, group_name: grp_name)
    }

    def user_name(id)
        User.find(id).name
    end
end