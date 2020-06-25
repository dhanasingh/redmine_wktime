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
  
  safe_attributes 'spent_id', 'spent_type', 'spent_for_id', 'spent_for_type'
  
  scope :time_entries,  -> { where(:spent_type => "TimeEntry") }
  scope :material_entries,  -> { where(:spent_type => "WkMaterialEntry") }
  scope :unbilled_entries,  -> { where(:invoice_item => nil) }
  
  scope :lastEntry, -> {
    joins("INNER JOIN time_entries TE ON TE.id = wk_spent_fors.spent_id AND spent_type = 'TimeEntry' AND user_id=#{User.current.id}")
    .joins("INNER JOIN (
      select  max(spent_on_time) as spent_on_time, spent_id, user_id 
      from wk_spent_fors
      INNER JOIN time_entries ON time_entries.id = wk_spent_fors.spent_id AND spent_type = 'TimeEntry' 
      where start_on is NOT NULL and end_on is NULL AND user_id=#{User.current.id}
      AND CURRENT_TIMESTAMP - spent_on_time < '24:00:00'
      group by spent_id, user_id
      ) as ST ON ST.spent_on_time = wk_spent_fors.spent_on_time AND TE.id =ST.spent_id")
    .joins("INNER JOIN issues I ON TE.issue_id= I.id")
    .joins("INNER JOIN trackers T ON I.tracker_id= T.id")
    .select("wk_spent_fors.start_on, wk_spent_fors.end_on, TE.project_id, TE.issue_id, TE.hours, TE.id, T.name")
  }
  
end
