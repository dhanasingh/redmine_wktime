# ERPmine - ERP for service industry
# Copyright (C) 2011-  Adhi software pvt ltd
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

class WkSurveyQueGroup < ApplicationRecord
  include LoadPatch::SurveyQuestionNestedSet

  belongs_to :wk_survey, class_name: 'WkSurvey', foreign_key: 'survey_id', inverse_of: :wk_survey_que_groups
  has_many :wk_survey_questions, -> { order(:lft) }, foreign_key: 'group_id', dependent: :destroy, inverse_of: :wk_survey_que_group

  accepts_nested_attributes_for :wk_survey_questions, allow_destroy: true

end