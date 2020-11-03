module WkleaverequestHelper
	include WktimeHelper

	def get_leave_type
		leaveType = Array.new
	    if Setting.plugin_redmine_wktime['wktime_leave'].present?
			leaveTypeIDs = Setting.plugin_redmine_wktime['wktime_leave'].map{ |entry| entry.split('|').first }
			leaveTypeIDs.delete(Setting.plugin_redmine_wktime['wktime_loss_of_pay'].split('|').first) if Setting.plugin_redmine_wktime['wktime_loss_of_pay'].present?
			leaveType = Issue.select(:id, :subject).where(id: leaveTypeIDs).collect{ |issue| [issue.subject, issue.id]}
		end
		leaveType
	end
	
	def getLeaveStatus
		{
			'N' => l(:wk_status_new),
			'S' => l(:wk_status_submitted),
			'A' => l(:wk_status_approved),
			'C' => l(:wk_status_cancelled),
			'R' => l(:wk_status_rejected)
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
end
