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

class WkSurveyQuestion < ActiveRecord::Base

  belongs_to :survey , :class_name => 'WkSurvey'
  has_many :wk_survey_choices, foreign_key: "survey_question_id", class_name: "WkSurveyChoice", :dependent => :destroy
  has_many :wk_survey_answers, foreign_key: "survey_question_id", class_name: "WkSurveyAnswer", :dependent => :destroy
  has_many :wk_survey_responses, through: :wk_survey_answers, source: :survey_response

  accepts_nested_attributes_for :wk_survey_choices, allow_destroy: true
  validates_presence_of :name

  def response_texts(group_name=nil)
    self.wk_survey_responses.where(group_name: group_name).select("wk_survey_answers.id, wk_survey_answers.choice_text")
  end
end