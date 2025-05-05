# ERPmine - ERP for service industry
# Copyright (C) 2011-2020  Adhi software pvt ltd
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

class WkLeaveReq < ApplicationRecord

  belongs_to :user
  belongs_to :leave_type, class_name: "Issue"
  has_many :wkstatus, -> { where(status_for_type: 'WkLeaveReq')}, foreign_key: "status_for_id", class_name: "WkStatus", :dependent => :destroy
  accepts_nested_attributes_for :wkstatus, allow_destroy: true

  validates_presence_of :leave_type, :start_date, :end_date

  scope :get_all, ->{
    joins(:user)
    .joins("INNER JOIN wk_statuses ON wk_statuses.status_for_id = wk_leave_reqs.id AND wk_statuses.status_for_type = 'WkLeaveReq'"+get_comp_con('wk_statuses')+"
      INNER JOIN
      (SELECT MAX(S.status_date) AS status_date, S.status_for_id
      FROM wk_leave_reqs AS LR
      INNER JOIN wk_statuses AS S ON S.status_for_id = LR.id AND S.status_for_type = 'WkLeaveReq' "+get_comp_con('S')+"
      GROUP BY S.status_for_id)
      AS S ON S.status_for_id = wk_leave_reqs.id AND S.status_date = wk_statuses.status_date")
    .select("wk_leave_reqs.*, wk_statuses.status")
  }

  scope :leaveReqSupervisor, -> {
    joins(:user).where("users.id = ? OR (users.parent_id = ?)", User.current.id, User.current.id)
  }

  scope :leaveReqUser, -> { where(user_id: User.current.id) }

  scope :leaveType, ->(type){
    where("wk_leave_reqs.leave_type_id =  ? ", type.to_i )
  }

  scope :leaveReqStatus, ->(status){
    where("wk_statuses.status =  ? ", status)
  }

  scope :userGroup, ->(id){
    joins("INNER JOIN groups_users ON groups_users.user_id = wk_leave_reqs.user_id")
    .where("groups_users.group_id =  ? ", id )
  }

  scope :groupUser, ->(id){
    joins(:user).where("wk_leave_reqs.user_id =  ? ", id )
  }

  scope :getEntry, ->(id){
    get_all.where(id: id).first
  }

  scope :dateFilter, ->(from, to){
    where(" wk_leave_reqs.start_date between ? and ? ", getFromDateTime(from), getToDateTime(to) )
  }

  def startDate
    self ? self.start_date.to_date : nil
  end

  def endDate
    self ? self.end_date.to_date : nil
  end

  def user_name
    self.user.name
  end

  def admingroupMail(userRole)
    user_mail = " SELECT address, E.user_id FROM wk_group_permissions
          INNER JOIN wk_permissions AS P1 ON P1.id = wk_group_permissions.permission_id"+get_comp_con('P1')+"
          INNER JOIN groups_users AS GU ON wk_group_permissions.group_id = GU.group_id
          INNER JOIN users AS U ON U.id = GU.user_id AND U.type IN ('User', 'AnonymousUser')"+get_comp_con('U')+"
          INNER JOIN email_addresses AS E ON E.user_id = U.id "+get_comp_con('E')+"
          INNER JOIN groups_users AS GU2 ON GU.user_id = GU2.user_id
          INNER JOIN wk_group_permissions AS GP ON GP.group_id = GU2.group_id"+get_comp_con('GP')+"
          INNER JOIN wk_permissions AS P2 ON P1.id = GP.permission_id "+get_comp_con('P2')
    if userRole == 'supervisor'
      user_mail =  user_mail + "where(P1.short_name = 'A_ATTEND' "+get_comp_con('wk_group_permissions')+" AND E.notify = #{ActiveRecord::Base.connection.adapter_name == 'SQLServer' ? 1 : true})"
    else
      user_mail = user_mail + "where(P1.short_name = 'R_LEAVE' AND "+get_comp_con('wk_group_permissions')+" E.notify = #{ActiveRecord::Base.connection.adapter_name == 'SQLServer' ? 1 : true})"
    end
    user_mail = user_mail + " Group BY address, E.user_id"
    user_mail = WkGroupPermission.find_by_sql(user_mail)
    # user_mail.pluck(:address)
    user_mail
  end

  def supervisor_mail
    if self.user.parent_id.blank?
      user_mail = admingroupMail('supervisor').pluck(:address)
      userID = user_mail.first
    else
      User.find(self.user.parent_id).mails
    end
  end

	def self.date_for_user_time_zone(y, m, d)
		if tz = User.current.time_zone
		  tz.local y, m, d
		else
		  Time.local y, m, d
		end
	end

	def self.getFromDateTime(dateVal)
		date_for_user_time_zone(dateVal.year, dateVal.month, dateVal.day).yesterday.end_of_day
	end

	def self.getToDateTime(dateVal)
		date_for_user_time_zone(dateVal.year, dateVal.month, dateVal.day).end_of_day
	end

  def status
    self.wkstatus.order(status_date: :desc).first&.status
  end

  def self.getApprovedLeaves(user_id, startdate)
    get_all.where(user_id: user_id, "wk_statuses.status" => "A",
      start_date: startdate..(startdate.to_date + 7.days), end_date: startdate..(startdate.to_date + 7.days))
  end
end
