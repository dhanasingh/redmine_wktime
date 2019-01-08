# ERPmine - ERP for service industry
# Copyright (C) 2011-2017  Adhi software pvt ltd
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

class WkMaterialEntry < ActiveRecord::Base
  unloadable
  validates_presence_of :project_id, :user_id, :issue_id, :quantity, :activity_id, :spent_on
  validates :spent_on, :date => true
  
  belongs_to :project
  belongs_to :issue
  belongs_to :user
  belongs_to :activity, :class_name => 'TimeEntryActivity'
  belongs_to :inventory_item, :class_name => 'WkInventoryItem'
  
  has_one :spent_for, as: :spent, class_name: 'WkSpentFor', :dependent => :destroy  
   
  # attr_protected :user_id, :tyear, :tmonth, :tweek
  
  accepts_nested_attributes_for :spent_for
  
  scope :visible, lambda {|*args|
    joins(:project).
    where(WkMaterialEntry.visible_condition(args.shift || User.current, *args))
  }
  scope :left_join_issue, lambda {
    joins("LEFT OUTER JOIN #{Issue.table_name} ON #{Issue.table_name}.id = #{WkMaterialEntry.table_name}.issue_id")
  }
  scope :on_issue, lambda {|issue|
    joins(:issue).
    where("#{Issue.table_name}.root_id = #{issue.root_id} AND #{Issue.table_name}.lft >= #{issue.lft} AND #{Issue.table_name}.rgt <= #{issue.rgt}")
  }

  
  
  # Returns a SQL conditions string used to find all time entries visible by the specified user
  def self.visible_condition(user, options={})
    Project.allowed_to_condition(user, :view_time_entries, options) do |role, user|
      if role.time_entries_visibility == 'all'
        nil
      elsif role.time_entries_visibility == 'own' && user.id && user.logged?
        "#{table_name}.user_id = #{user.id}"
      else
        '1=0'
      end
    end
  end

  # Returns true if user or current user is allowed to view the time entry
  def visible?(user=nil)
    (user || User.current).allowed_to?(:view_time_entries, self.project) do |role, user|
      if role.time_entries_visibility == 'all'
        true
      elsif role.time_entries_visibility == 'own'
        self.user == user
      else
        false
      end
    end
  end
  
  # Returns true if the time entry can be edited by usr, otherwise false
  def editable_by?(usr)
    visible?(usr) && (
      (usr == user && usr.allowed_to?(:edit_own_time_entries, project)) || usr.allowed_to?(:edit_time_entries, project)
    )
  end
  
  # Returns the custom_field_values that can be edited by the given user
  def editable_custom_field_values(user=nil)
    visible_custom_field_values
  end
  
  def spent_on=(date)
    super
    self.tyear = spent_on ? spent_on.year : nil
    self.tmonth = spent_on ? spent_on.month : nil
    self.tweek = spent_on ? Date.civil(spent_on.year, spent_on.month, spent_on.day).cweek : nil
  end
end
