# ERPmine - ERP for service industry
# Copyright (C) 2011-2021  Adhi software pvt ltd
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class WkSurvey < ApplicationRecord

	belongs_to :group , :class_name => 'Group'
  belongs_to :survey_for, :polymorphic => true
  has_many :wk_survey_questions, foreign_key: "survey_id", class_name: "WkSurveyQuestion", :dependent => :destroy, inverse_of: :survey
  has_many :wk_survey_choices, through: :wk_survey_questions
  has_many :wk_survey_responses, foreign_key: "survey_id", :dependent => :destroy
  has_many :wk_survey_answers, through: :wk_survey_responses
  has_many :notifications, as: :source, class_name: "WkUserNotification", :dependent => :destroy
  has_many :wk_survey_que_groups, foreign_key: "survey_id", dependent: :destroy, inverse_of: :wk_survey

  accepts_nested_attributes_for :wk_survey_questions, allow_destroy: true
  accepts_nested_attributes_for :wk_survey_que_groups, allow_destroy: true

  validates_presence_of :name
  after_save :survey_notification

  scope :surveyTextQuestion, ->(survey_id){
      joins(:wk_survey_questions)
      .where("wk_surveys.id = #{survey_id} AND wk_survey_questions.question_type IN ('TB', 'MTB') AND
          wk_survey_questions.not_in_report = #{ActiveRecord::Base.connection.adapter_name == 'SQLServer' ? 0 : false} ")
      .select("wk_surveys.id, wk_surveys.name, wk_survey_questions.id AS question_id, wk_survey_questions.name AS question_name")
      .order("wk_surveys.id, wk_survey_questions.id")
  }

  scope :getTextAnswer, ->(survey_id, surveyForType){
    surveyTextQuestion(survey_id).joins(:wk_survey_answers)
    .where(" wk_survey_questions.id = wk_survey_answers.survey_question_id AND
      wk_survey_responses.survey_for_type " + (surveyForType.blank? ? " IS NULL " : " = '#{surveyForType}'"))
    .select("wk_survey_answers.choice_text")
  }

  scope :responsedTextAnswer, ->(groupName){
    where("wk_survey_responses.group_name = '#{groupName}'")
    .order("wk_survey_answers.survey_response_id")
  }

  scope :currentRespTxtAnswer, -> {
    where("wk_survey_responses.group_name IS NULL")
    .order("wk_survey_answers.survey_response_id")
  }

  scope :getSurveyChoices, ->(survey_id, question_id){
    joins(:wk_survey_questions, :wk_survey_choices)
    .where("wk_surveys.id = #{survey_id} and wk_survey_choices.survey_question_id = #{question_id}")
    .select("wk_survey_choices.name")
    .group("wk_survey_choices.name")
  }

  scope :with_total_points, ->(surveyForId){
    joins("LEFT JOIN wk_survey_responses ON wk_survey_responses.survey_id = wk_surveys.id AND wk_survey_responses.survey_for_id = #{surveyForId.to_i}")
    .select("wk_surveys.*, wk_survey_responses.total_points")
  }

  def self.getMailUsers(user_group)
    users =  User.where({status: true})
    if user_group.present?
      users = users.joins('INNER JOIN groups_users ON users.id = user_id').where("groups_users.group_id = #{user_group}")
    end
    users
  end

  def self.surveyAvgQuestion(survey_id, question_id)
    castFormat = case ActiveRecord::Base.connection.adapter_name
    when "PostgreSQL"
      "INT"
    when "Mysql2"
      "SIGNED"
    when "SQLServer"
      "INT"
    else
      "INTEGER"
    end

    WkSurvey.joins(wk_survey_questions: { wk_survey_choices: :wk_survey_answers }, wk_survey_responses: :wk_survey_answers)
    .where("wk_surveys.id = #{survey_id} and wk_survey_questions.id = #{question_id} ")
    .select("SUM(CAST(wk_survey_choices.name AS #{castFormat}))/count(wk_survey_responses.user_id) AS questionavg, wk_survey_questions.id AS question_id, wk_surveys.id AS survey_id, CASE WHEN wk_survey_responses.group_name IS NULL THEN 'Current' ELSE wk_survey_responses.group_name END AS grpname")
    .group("wk_surveys.id, wk_survey_questions.id, wk_survey_responses.group_date, wk_survey_responses.group_name")
  end

  def getGroupName
    survey_response = self.wk_survey_responses.where("wk_survey_responses.user_id =  ? ", User.current.id)
      .order("wk_survey_responses.updated_at").last
    group_name = survey_response.try(:group_name)
  end

  def survey_notification
    if status? && status == "C" && WkNotification.notify('surveyClosed')
      emailNotes = "Survey : " + (self.name) + " has been closed " + "\n\n" + l(:label_redmine_administrator)
      userId = survey_for_type == 'User' && survey_for_id.present? ? User.where(id: survey_for_id).pluck(:id) : WkSurvey.getMailUsers(group_id).pluck(:id)
      subject = l(:label_survey) + " " + l(:label_notification)
      WkNotification.notification(userId, emailNotes, subject, self, 'surveyClosed')
    end
  end

  def result_questions
    self.wk_survey_questions.where(not_in_report: false)
  end
end