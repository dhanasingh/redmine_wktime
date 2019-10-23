class WkLeaveReq < ActiveRecord::Base
  unloadable

  belongs_to :user
  belongs_to :leave_type, class_name: "Issue"
  has_many :wkstatus, -> { where(status_for_type: 'WkLeaveReq')}, foreign_key: "status_for_id", class_name: "WkStatus", :dependent => :destroy
  accepts_nested_attributes_for :wkstatus, allow_destroy: true

  validates_presence_of :leave_type, :start_date, :end_date
  
  scope :get_all, ->{
    joins(:wkstatus, :user, :leave_type).select("wk_leave_reqs.*, wk_statuses.status")
    .where("status_date = (SELECT MAX(S.status_date) FROM wk_statuses AS S WHERE S.status_for_id = wk_leave_reqs.id GROUP BY S.status_for_id)")
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
    joins(:user).where("users.id =  ? ", id )
  }

  scope :getEntry, ->(id){
    get_all.where(id: id).first
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

  def supervisor_mail
    if self.user.parent_id.blank?
      userID = WkGroupPermission.joins(:permission).joins("INNER JOIN groups_users ON groups_users.group_id = wk_group_permissions.group_id")
        .where("wk_permissions.short_name = 'ADM_ERP'").select("groups_users.user_id").first
      userID.blank? ? nil : User.find(userID.user_id).mail
    else
      User.find(self.user.parent_id).mail
    end
  end
end
