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

class WkUserLeave < ApplicationRecord

  include Redmine::SafeAttributes
  belongs_to :user
  belongs_to :issue, :class_name => 'Issue', :foreign_key => 'issue_id'

  # attr_protected :user_id, :issue_id
  safe_attributes 'balance', 'issue_id', 'accrual_on', 'used', 'accrual'

  scope :leaveAvailableHours, ->(issue_id, user_id){
    joins("INNER JOIN (select  max(accrual_on) as accrual_on from wk_user_leaves " + get_comp_con('wk_user_leaves', 'WHERE') + " ) as LAH ON LAH.accrual_on = wk_user_leaves.accrual_on")
    .where("user_id=#{user_id} and issue_id=#{issue_id}")
    .select("user_id, issue_id, balance, accrual, used")
  }

  def self.leaveCounts
    accrualLeaves = []
    (getLeaves || []).map do |el|
      el = el.split("|")
      accrualLeaves << el.first.to_i if el[1].present? && (el[1].to_i) > 0
    end
    WkUserLeave.joins(:issue).joins(:user)
    .joins("inner join (select MAX(accrual_on) as accrual_on, user_id, issue_id
      from wk_user_leaves AS UL
      inner join users AS U ON U.id = UL.user_id AND U.type = 'User' AND U.status = 1
      where UL.user_id=#{User.current.id} " + get_comp_con('UL') + get_comp_con('U') +" 
      group by user_id, issue_id
      ) AS l on l.accrual_on = wk_user_leaves.accrual_on AND l.user_id = wk_user_leaves.user_id AND l.issue_id = wk_user_leaves.issue_id")
      .where("wk_user_leaves.user_id=#{User.current.id} AND wk_user_leaves.issue_id IN (?)", accrualLeaves)
      .select("(wk_user_leaves.balance + wk_user_leaves.accrual - wk_user_leaves.used) AS leave_count, wk_user_leaves.user_id, wk_user_leaves.issue_id, subject")
  end

  def self.detailReport(issueID)
    WkUserLeave.joins(:issue).joins(:user)
    .where(user_id: User.current.id, issue_id: issueID)
    .order(accrual_on: "DESC")
  end

  def self.getLeaves
		leaveSettings = WkSetting.where("name = ?", 'leave_settings' ).pluck(:value).first
		leaveSettings = JSON.parse(leaveSettings) if leaveSettings.present?
    leaveSettings
	end

  def self.getLeaveName(issueID)
    Issue.where(id: issueID).first&.subject
  end
end