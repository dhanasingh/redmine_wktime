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

class WkUserSalaryComponents < ActiveRecord::Base
  unloadable
  include Redmine::SafeAttributes
  
  belongs_to :user
  belongs_to :wk_salary_components, :class_name => 'WkSalaryComponents', :foreign_key => 'salary_component_id'
  belongs_to :wk_salary_components, :class_name => 'WkSalaryComponents', :foreign_key => 'dependent_id'
  
  attr_protected :user_id, :salary_component_id, :dependent_id
end
