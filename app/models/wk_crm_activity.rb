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

class WkCrmActivity < ActiveRecord::Base
  unloadable
  belongs_to :parent, :polymorphic => true
  belongs_to :created_by_user, :class_name => 'User'
  belongs_to :assigned_user, :class_name => 'User'
  validate :validate_crm_activity
  before_save :update_status_update_on 
  
  def validate_crm_activity
	errors.add(:base, (l(:label_subject)  + " " + l('activerecord.errors.messages.blank'))) if name.blank?
	# if activity_type == 'T'
		# errors.add :start_date, :blank if name.blank?
		# errors.add :end_date, :blank if name.blank?
	# end
	
	# if activity_type == 'T'
		# errors.add :start_date, :blank if name.blank?
		# errors.add :end_date, :blank if name.blank?
	# end
	
	# if activity_type == 'M'
		# errors.add :start_date, :blank if name.blank?
	# end
	
  end
  
  def update_status_update_on
	self.status_update_on = DateTime.now if status_changed?
  end
  
end
