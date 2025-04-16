module WkleaverequestHelper
	include WktimeHelper

	def get_leave_type
		leaveType = Array.new
	    if getLeaveSettings.present?
			leaveTypeIDs = getLeaveSettings.map{ |entry| entry.split('|').first }
			leaveTypeIDs.delete(Setting.plugin_redmine_wktime['wktime_loss_of_pay'].split('|').first) if Setting.plugin_redmine_wktime['wktime_loss_of_pay'].present?
			leaveType = Issue.select(:id, :subject).where(id: leaveTypeIDs).collect{ |issue| [issue.subject, issue.id]}
		end
		leaveType
	end
	
	def getLeaveStatus
		{
			'N' => l(:label_new),
			'S' => l(:wk_status_submitted),
			'A' => l(:wk_status_approved),
			'C' => l(:wk_status_cancelled),
			'R' => l(:default_issue_status_rejected)
		}
	end

	def isLeaveReqAdmin
		validateERPPermission("A_ATTEND") || isSupervisor
	end

	def getButtonLabels
		buttonLabel = Hash.new
		isUser = @leaveReqEntry.try(:user_id) == User.current.id
		case(@leaveReqStatus)
			when 'S'
				if (isLeaveReqAdmin && !isUser)
					buttonLabel['A'] = 'button_wk_approve'
					buttonLabel['R'] = 'button_wk_reject'
				else
					buttonLabel['N'] = 'button_wk_unsubmit'
					buttonLabel['C'] = 'button_cancel_leave'
				end
			when 'A'
				buttonLabel['S'] = 'button_wk_unapprove' if (isLeaveReqAdmin && !isUser)
			when 'N'
				if isUser
					buttonLabel['S'] = 'button_submit'
					buttonLabel['C'] = 'button_cancel_leave'
				end	
			when 'R'
				if isUser
					buttonLabel['S'] = 'button_submit'
					buttonLabel['C'] = 'button_cancel_leave'
				end
			when ''
				buttonLabel['S'] = 'button_submit'
		end
		buttonLabel
	end

	def getLeaveHours(userId)
		available_hours = 0
		leave_available = []
		get_leave_type.each do |subject, issue_id|
			userHours = WkUserLeave.leaveAvailableHours(issue_id, userId).first
			available_hours = userHours.balance + userHours.accrual - userHours.used  if userHours.present?
			leave_available << { issue_id => available_hours}
		end
		leave_available
	end

  def get_status_date(leaveReq, status)
    status_date = leaveReq.wkstatus.where(status: status).order(status_date: :desc).first&.status_date
  end
end
