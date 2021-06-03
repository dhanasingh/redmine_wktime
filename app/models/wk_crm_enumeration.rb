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

class WkCrmEnumeration < ActiveRecord::Base
  before_save :check_default
  validates_presence_of :name
  has_many :skillsets, class_name: :WkSkill, foreign_key: :skill_set_id, dependent: :destroy

  def check_default
    if is_default? && is_default_changed?
      WkCrmEnumeration.where({:enum_type => enum_type}).update_all({:is_default => false})
    end
  end

end