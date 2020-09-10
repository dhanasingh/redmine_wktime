# ERPmine - ERP for service industry
# Copyright (C) 2011-2016  Adhi software pvt ltd
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

class WkSpentFor < ActiveRecord::Base
  include Redmine::SafeAttributes
  belongs_to :spent_for, :polymorphic => true
  belongs_to :spent, :polymorphic => true
  belongs_to :invoice_item , :class_name => 'WkInvoiceItem'
  attr_accessor :spent_date_hr, :spent_date_min, :spent_for_key
  
  safe_attributes 'spent_id', 'spent_type', 'spent_for_id', 'spent_for_type', 'end_on', 's_longitude', 's_latitude',
   'e_longitude', 'e_latitude', 'clock_action'
  
  scope :time_entries,  -> { where(:spent_type => "TimeEntry") }
  scope :material_entries,  -> { where(:spent_type => "WkMaterialEntry") }
  scope :unbilled_entries,  -> { where(:invoice_item => nil) }

  scope :getIssueLog, -> (id=nil, spent_type=nil) {
    joins("LEFT JOIN time_entries AS TE ON TE.id = wk_spent_fors.spent_id AND spent_type = 'TimeEntry' AND TE.user_id = #{User.current.id}")
    .joins("LEFT JOIN wk_material_entries AS M ON M.id = wk_spent_fors.spent_id AND spent_type = 'WkMaterialEntry' AND M.user_id = #{User.current.id}")
    .joins("LEFT JOIN issues AS I ON I.id = TE.issue_id OR I.id = M.issue_id")
    .joins("LEFT JOIN projects AS P ON P.id = I.project_id")
    .joins("LEFT JOIN trackers AS T ON I.tracker_id = T.id")
    .where("(M.id IS NOT NULL OR TE.id IS NOT NULL) AND  " + (id.present? ? " spent_id = #{id}" : "wk_spent_fors.clock_action = 'S'") +
      (spent_type.present? ? " AND wk_spent_fors.spent_type = '#{getSpentType(spent_type)}'" : ""))
    .select("wk_spent_fors.*, P.name AS project_name, I.subject, I.id AS issue_id, T.name AS tracker_name")
    .order("spent_on_time DESC")
  }

  def self.getSpentType(spent_type)
    case spent_type
    when 'T'
      return "TimeEntry"
    when 'A'
      return "WkMaterialEntry"
    end
  end
end
