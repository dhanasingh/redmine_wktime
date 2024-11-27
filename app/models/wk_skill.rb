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

class WkSkill < ApplicationRecord
  belongs_to :user
  belongs_to :skill_set, class_name: "WkCrmEnumeration"
  has_many :groups, through: :user
  belongs_to :source, :polymorphic => true

  validates_presence_of :skill_set
  validates_numericality_of :rating, :experience

  scope :get_entries, ->(type){ joins(:skill_set).joins(:user).where({source_type: type}) }
  scope :filterByID, ->(id){ where(source_id: id) }
  scope :skillSet, ->(skill_set){ where(skill_set_id: skill_set)}
  scope :groupUser, ->(id){ where("users.id = ? ", id)}
  scope :rating, ->(rating){ where("rating >= ?", rating)}
  scope :lastUsed, ->(last_used){ where("last_used >= ?", last_used)}
  scope :experience, ->(experience){ where("experience >= ?", experience)}
  scope :interest_level, ->(interest_level){ where("interest_level >= ?", interest_level)}
  scope :userGroup, ->(id){
    joins(:groups)
    .where("groups_users.group_id =  ? ", id)
  }
end
