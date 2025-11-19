# app/models/wk_s_survey_group.rb
class WkSurveyQueGroup < ApplicationRecord
  belongs_to :wk_survey, class_name: 'WkSurvey', foreign_key: 'survey_id', inverse_of: :wk_survey_que_groups
  has_many :wk_survey_questions, foreign_key: 'group_id', dependent: :destroy, inverse_of: :wk_survey_que_group

  accepts_nested_attributes_for :wk_survey_questions, allow_destroy: true

end