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

class Wktime < ActiveRecord::Base
unloadable
include Redmine::SafeAttributes

  belongs_to :user
  belongs_to :submitter, :class_name => 'User', :foreign_key => 'submitter_id'
  belongs_to :updater, :class_name => 'User', :foreign_key => 'statusupdater_id'
  
  acts_as_customizable
  
  # attr_protected :user_id, :submitter_id, :statusupdater_id
  safe_attributes 'hours', 'notes', 'begin_date', 'status', 'submitted_on', 'statusupdate_on'

  validates_presence_of :user_id, :hours, :begin_date, :status
  validates_numericality_of :hours, :message => :invalid
  validates_length_of :notes, :maximum => 255, :allow_nil => true
  validate :validate_wktime

  def initialize(attributes=nil, *args)
    super
  end
  
  def validate_wktime
    errors.add :hours, :invalid if hours && (hours < 0 || hours >= 1000)
#    errors.add :user_id, :invalid if user.nil?
#	errors.add :submitter_id, :invalid if submitter.nil?
#    errors.add :statusupdater_id, :invalid if approver.nil?
  end
  
  def hours=(h)
    write_attribute :hours, (h.is_a?(String) ? (h.to_hours || h) : h)
  end

  def hours
    h = read_attribute(:hours)
    if h.is_a?(Float)
      h.round(2)
    else
      h
    end
  end

    def submitted_on=(date)
		super
		if submitted_on.is_a?(Time)
		  self.submitted_on = submitted_on.to_date
		end
	end
	
	def statusupdate_on=(date)
		super
		if statusupdate_on.is_a?(Time)
		  self.statusupdate_on = statusupdate_on.to_date
		end
	end

end
