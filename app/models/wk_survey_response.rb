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

class WkSurveyResponse < ApplicationRecord

  belongs_to :survey, :class_name => 'WkSurvey'
  belongs_to :user
  has_many :wk_survey_answers, foreign_key: "survey_response_id", :dependent => :destroy
  # has_many :wk_statuses, foreign_key: "status_for_id", dependent: :destroy, -> { where(status_for_type: 'WkSurveyResponse') }
  has_many :wk_statuses, -> { where(status_for_type: 'WkSurveyResponse') }, foreign_key: "status_for_id", dependent: :destroy



  has_many :wk_survey_reviews, foreign_key: "survey_response_id", :dependent => :destroy
  has_one :current_status, ->{
    joins("INNER JOIN (
      SELECT status_for_id, MAX(status_date) AS status_date
      FROM wk_statuses WHERE status_for_type='WkSurveyResponse' " + get_comp_con('wk_statuses') + "
      GROUP BY status_for_id
    ) AS CS ON CS.status_for_id = wk_statuses.status_for_id AND CS.status_date = wk_statuses.status_date")
  }, class_name: "WkStatus", foreign_key: "status_for_id", :dependent => :destroy

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

  def self.getClosedDate(groupName)
    where(group_name: groupName).first&.group_date
  end

  def user_name(id)
    User.find(id).name
  end

  def self.getCurrentResponse(survey_id, response_id=nil, surveyForID=nil, surveyForType=nil)
    condStr = ""
    if response_id.present?
      condStr += " AND wk_survey_responses.id = #{response_id.to_i}"
    else
      condStr += " AND (wk_survey_responses.user_id = #{User.current.id}) " if surveyForID.blank?
      condStr += " AND wk_survey_responses.survey_for_type" +
        (surveyForID.blank? ? " IS NULL " : " = '#{surveyForType}' ") + " AND wk_survey_responses.survey_for_id" +
        (surveyForID.blank? ? " IS NULL " : " = #{surveyForID} ")
    end

    addDate = case ActiveRecord::Base.connection.adapter_name
    when "SQLServer"
      " DATEADD(d, recur_every, wk_statuses.status_date) "
    when "PostgreSQL"
      " (wk_statuses.status_date + interval '1' day * recur_every) "
    when "Mysql2"
      " DATE_ADD(wk_statuses.status_date, INTERVAL recur_every DAY) "
    # when "SQLite"
    #   " datetime(ST.status_date, '+'||recur_every||' days') "
    else
      " datetime(wk_statuses.status_date, '+'||recur_every||' days') "
    end

    # surveyResponse = WkSurveyResponse.joins("INNER JOIN wk_surveys ON wk_survey_responses.survey_id = wk_surveys.id")
    # .joins("INNER JOIN wk_statuses AS ST ON status_for_type = 'WkSurveyResponse' AND status_for_id = wk_survey_responses.id")
    # .joins("INNER JOIN (
    #     SELECT status_for_id AS id, max(status_date) AS status_date
    #     FROM wk_statuses
    #     WHERE status_for_type = 'WkSurveyResponse' " + get_comp_con('wk_statuses') + "
    #     GROUP BY status_for_id
    #   ) AS CR ON CR.id = wk_survey_responses.id AND CR.status_date = ST.status_date")
    # .where("wk_surveys.id = #{survey_id}"+ condStr + get_comp_con('ST') + get_comp_con('wk_surveys'))
    # .select("ST.status, ST.status_date, wk_survey_responses.*")
    # .order("ST.status_date desc")
    surveyResponse = WkSurveyResponse.joins(:survey, :wk_statuses)
    .joins("INNER JOIN (
        SELECT status_for_id AS id, max(status_date) AS status_date
        FROM wk_statuses
        WHERE status_for_type = 'WkSurveyResponse' " + get_comp_con('wk_statuses') + "
        GROUP BY status_for_id
      ) AS CR ON CR.id = wk_survey_responses.id AND CR.status_date = wk_statuses.status_date")
    .where("wk_surveys.id = #{survey_id}"+ condStr)
    .select("wk_statuses.status, wk_statuses.status_date, wk_survey_responses.*")
    .order("wk_statuses.status_date desc")
    surveyResponse = surveyResponse.where("(wk_surveys.status = 'O' AND recur = ? AND (" + addDate + " > ?) OR wk_surveys.status != 'O' OR recur != ?) ", true, Time.now(), true) if response_id.blank?
    surveyResponse.first
  end

  def self.response_list(survey, groupName, survey_privilege, users, surveyForType)
    condStr = survey_privilege ? "" : (survey.is_review ? " AND (U.id IN (#{users}) OR U.parent_id = #{User.current.id}) " : " AND  U.id = #{User.current.id} ")
    if groupName.blank?
      condStr += " AND group_name IS NULL"
    else
      condStr += groupName == "ALL" ? " " : " AND group_name = '#{groupName}' "
    end
    surveyForType = surveyForType.blank? ? " IS NULL " : " = '#{surveyForType}'"

    # self.joins("INNER JOIN wk_statuses AS ST ON ST.status_for_id = wk_survey_responses.id
    #   AND ST.status_for_type = 'WkSurveyResponse'")
    # .joins("INNER JOIN (
    #   SELECT status_for_id AS id, max(status_date) AS status_date
    #   FROM wk_statuses
    #   WHERE status_for_type = 'WkSurveyResponse' " + get_comp_con('wk_statuses') + "
    #   GROUP BY status_for_id
    # ) AS CR ON CR.id = wk_survey_responses.id AND CR.status_date = ST.status_date")
    # .joins("INNER JOIN wk_surveys AS S ON S.id = wk_survey_responses.survey_id
    #   INNER JOIN users AS U ON U.id = user_id AND U.type = 'User'")
    #   .where("survey_id = #{survey.id} " + " AND wk_survey_responses.survey_for_type " + surveyForType + condStr + get_comp_con('ST') + get_comp_con('S') + get_comp_con('U'))
    #   .group("survey_id, wk_survey_responses.id, S.name, S.survey_for_type, S.survey_for_id, ST.status, U.firstname, U.lastname, U.parent_id, wk_survey_responses.group_name, wk_survey_responses.user_id, wk_survey_responses.survey_for_id")
    #   .select("MAX(ST.status_date) AS status_date, ST.status, survey_id, wk_survey_responses.group_name, wk_survey_responses.id, user_id, S.name,
    #   S.survey_for_type, wk_survey_responses.survey_for_id, U.firstname, U.lastname, U.parent_id").order("user_id ASC")
    self.joins(:wk_statuses, :survey)
    .joins("INNER JOIN (
      SELECT status_for_id AS id, max(status_date) AS status_date
      FROM wk_statuses
      WHERE status_for_type = 'WkSurveyResponse' " + get_comp_con('wk_statuses') + "
      GROUP BY status_for_id
    ) AS CR ON CR.id = wk_survey_responses.id AND CR.status_date = wk_statuses.status_date")
    .joins("INNER JOIN users AS U ON U.id = user_id AND U.type = 'User'")
      .where("survey_id = #{survey.id} " + " AND wk_survey_responses.survey_for_type " + surveyForType)
      .group("survey_id, wk_survey_responses.id, wk_surveys.name, wk_surveys.survey_for_type, wk_surveys.survey_for_id, wk_statuses.status, U.firstname, U.lastname, U.parent_id, wk_survey_responses.group_name, wk_survey_responses.user_id, wk_survey_responses.survey_for_id")
      .select("MAX(wk_statuses.status_date) AS status_date, wk_statuses.status, survey_id, wk_survey_responses.group_name, wk_survey_responses.id, user_id, wk_surveys.name,
      wk_surveys.survey_for_type, wk_survey_responses.survey_for_id, wk_survey_responses.total_points, wk_survey_responses.total_points, U.firstname, U.lastname, U.parent_id").order("user_id ASC")
  end
end