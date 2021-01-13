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

class WkSurveyResponse < ActiveRecord::Base

  belongs_to :survey, :class_name => 'WkSurvey'
  belongs_to :user
  has_many :wk_survey_answers, foreign_key: "survey_response_id", :dependent => :destroy
  has_many :wk_statuses, foreign_key: "status_for_id", :dependent => :destroy
  has_many :wk_survey_reviews, foreign_key: "survey_response_id", :dependent => :destroy
  has_one :current_status, ->{
    joins("INNER JOIN (
      SELECT status_for_id, MAX(status_date) AS status_date
      FROM wk_statuses WHERE status_for_type='WkSurveyResponse'
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

  def user_name(id)
    User.find(id).name
  end

  def self.getCurrentResponse(survey_id, response_id=nil, surveyForID=nil, surveyForType=nil)
    condStr = ""
    if !response_id.blank?
      condStr += " AND wk_survey_responses.id = #{response_id.to_i}"
    else
      condStr += " AND (wk_survey_responses.user_id = #{User.current.id}) " if surveyForID.blank?
      condStr += " AND wk_survey_responses.survey_for_type" +
        (surveyForID.blank? ? " IS NULL " : " = '#{surveyForType}' ") + " AND wk_survey_responses.survey_for_id" +
        (surveyForID.blank? ? " IS NULL " : " = #{surveyForID} ")
    end

    if "SQLServer" == ActiveRecord::Base.connection.adapter_name
      dateDiff = "(DATEDIFF(y, '#{Time.now()}', ST.status_date))"
    else
      dateDiff = "(CAST('#{Time.now()}' AS DATE) - CAST(ST.status_date AS DATE))"
    end

    WkSurveyResponse.joins("INNER JOIN wk_surveys ON wk_survey_responses.survey_id = wk_surveys.id")
    .joins("INNER JOIN wk_statuses AS ST ON status_for_type = 'WkSurveyResponse' AND status_for_id = wk_survey_responses.id")
    .joins("INNER JOIN (
        SELECT status_for_id AS id, max(status_date) AS status_date
        FROM wk_statuses
        WHERE status_for_type = 'WkSurveyResponse'
        GROUP BY status_for_id
      ) AS CR ON CR.id = wk_survey_responses.id AND CR.status_date = ST.status_date")
    .where("wk_surveys.id = #{survey_id} AND (wk_surveys.status = 'O' AND recur = ? AND (recur_every > " + dateDiff + ") OR wk_surveys.status != 'O' OR recur != ?) " + condStr, true, true)
    .select("ST.status, ST.status_date, wk_survey_responses.*")
    .first
  end
end