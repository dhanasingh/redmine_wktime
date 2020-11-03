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

class WkleaverequestController < WkbaseController
  menu_item :wkattendance
  include WkleaverequestHelper
	include WkpayrollHelper
  include WksurveyHelper

  def index
    sort_init 'start_date', 'desc'
		sort_update 'user_name' => "CONCAT(users.firstname, users.lastname)",
                'leave_type' => "issues.subject",
                'start_date' => "start_date",
                'end_date' => "end_date",
                'submitted_date' => "created_at",
                'status' => "wk_statuses.status"
    set_filter_session
    getUsersAndGroups
    retrieve_date_range
    lveReqEntires = WkLeaveReq.get_all
    lveReqEntires = lveReqEntires.leaveReqSupervisor if isSupervisor && !validateERPPermission("A_ATTEND")
    lveReqEntires = lveReqEntires.leaveReqUser unless isSupervisor || validateERPPermission("A_ATTEND")

    lveReqEntires = lveReqEntires.leaveType(session[controller_name][:leave_type]) if session[controller_name].try(:[], :leave_type).present?
    lveReqEntires = lveReqEntires.userGroup(session[controller_name][:group_id]) if session[controller_name].try(:[], :group_id).present? && session[controller_name].try(:[], :group_id) != "0"
    lveReqEntires = lveReqEntires.groupUser(session[controller_name][:user_id]) if session[controller_name].try(:[], :user_id).present? && session[controller_name].try(:[], :user_id) != "0"
    lveReqEntires = lveReqEntires.leaveReqStatus(session[controller_name][:lveStatus]) if session[controller_name].try(:[], :lveStatus).present?
    lveReqEntires = lveReqEntires.dateFilter(@from, @to) if !@from.blank? && !@to.blank?
    
    lveReqEntires = lveReqEntires.order("user_id ASC, start_date DESC").reorder(sort_clause)
    @leave_count = lveReqEntires.length
    @leave_pages = Paginator.new @leave_count, per_page_option, params['page']
    @leaveReqEntires = lveReqEntires.limit(@leave_pages.per_page).offset(@leave_pages.offset).to_a
  end

  def edit
    if params[:id].present?
      @leaveReqEntry = WkLeaveReq.getEntry(params[:id])
    else
      @leaveReqEntry = nil
    end
    isCurrentUser = @leaveReqEntry.blank? || @leaveReqEntry.user_id == User.current.id
    @leaveReqStatus = @leaveReqEntry.present? ? @leaveReqEntry.try(:status) : ''
    @readonly = ['C', 'A', 'S'].include?(@leaveReqStatus) || (!isCurrentUser && ['N', 'R'].include?(@leaveReqStatus))
  end

  def save
    user = User.current
    newEntry = params[:lveReqID].blank?
    leaveReq = newEntry ? WkLeaveReq.new : WkLeaveReq.find(params[:lveReqID])
    leaveReq.user_id = user.id if newEntry
    leaveReq.leave_type_id = params[:leave_type_id] if newEntry
    leaveReq.start_date = params[:start_date] if params[:start_date].present?
    leaveReq.end_date = params[:end_date] if params[:end_date].present?
    leaveReq.leave_reasons = params[:leave_reasons] if params[:leave_reasons].present?
    leaveReq.reviewer_comment = params[:reviewer_comment] if params[:reviewer_comment].present?

    lveReqStatus = 'S'
    params.each do |param, val|
      lveReqStatus = param.split('_').last if param.include?("submit_")
    end
    wkstatus = [{status_for_type: "WkLeaveReq", status: lveReqStatus, status_date: Time.now, status_by_id: user.id}]
    leaveReq.wkstatus_attributes = wkstatus if leaveReq.wkstatus.blank? || leaveReq.wkstatus.last.status != status

    if leaveReq.save
      leaveReqMail(leaveReq)
    else
      flash[:error] = leaveReq.errors.full_messages.join('<br>')
			redirect_to action: 'edit', id: params[:id]
    end
  end

  def leaveReqMail(leaveReq)
    user = User.current
    leaveReq = WkLeaveReq.getEntry(leaveReq.id)
    isUser = user.id == leaveReq.user_id
    status = getLeaveStatus[leaveReq.status]
    if WkNotification.notify('leaveRequested') && leaveReq.status == 'S' || WkNotification.notify('leaveApproved') &&
      ['A','R'].include?(leaveReq.status)
      if (leaveReq.status == 'S' && isUser) 
        email_id = leaveReq.supervisor_mail
      elsif (['A','R', 'S'].include?(leaveReq.status) && !isUser)
        email_id = leaveReq.user.mails
        status = "UnApproved" if leaveReq.status == 'S'
      end
      ccMailId = leaveReq.admingroupMail('leaveNotifyUser') - [email_id]
      if email_id.present?
        emailNotes = l(:label_leave_email_note).to_s + " #{status} #{l(:label_by)} " + user.name
        emailNotes += "\n\n" + "#{l(:field_user)}: " + leaveReq.user_name
        emailNotes += "\n" + l(:label_leave_type).to_s + ": " + leaveReq.leave_type.subject
        emailNotes += "\n" + l(:label_start_date).to_s + ": " + leaveReq.startDate.to_s + " " + l(:label_end_date) + ": " + leaveReq.endDate.to_s
        emailNotes += "\n" + l(:label_status).to_s + ": " + status
        emailNotes += "\n" + l(:label_reason).to_s + ": " + leaveReq.leave_reasons if leaveReq.leave_reasons.present?
        err_msg = sent_emails(l(:label_leave_request_notification), user.language, email_id, emailNotes, ccMailId)
      end
    end
    redirect_to action: 'index' , tab: 'wkleaverequest'
    flash[:notice] = l(:notice_successful_update)
    flash[:error] = err_msg if err_msg.present?
  end
	
	def set_filter_session
		session[controller_name] = {:from => @from, :to => @to} if session[controller_name].nil?
    if params[:searchlist] == controller_name
			session[controller_name] = Hash.new if session[controller_name].nil?
			filters = [:group_id, :user_id, :leave_type, :lveStatus, :period, :from, :to]
			filters.each do |param|
				if params[param].blank? && session[controller_name].try(:[], param).present?
					session[controller_name].delete(param)
				elsif params[param].present?
					session[controller_name][param] = params[param]
				end
			end
		end
  end

  def retrieve_date_range
		@free_period = false
		@from, @to = nil, nil
		period_type = session[controller_name].try(:[], :period_type)
		period = session[controller_name].try(:[], :period)
		fromdate = session[controller_name].try(:[], :from)
		todate = session[controller_name].try(:[], :to)
		
		if (period_type == '1' || (period_type.nil? && !period.nil?)) 
		    case period.to_s
			  when 'today'
				@from = @to = Date.today
			  when 'yesterday'
				@from = @to = Date.today - 1
			  when 'current_week'
				@from = getStartDay(Date.today - (Date.today.cwday - 1)%7)
				@to = @from + 6
			  when 'last_week'
				@from =getStartDay(Date.today - 7 - (Date.today.cwday - 1)%7)
				@to = @from + 6
			  when '7_days'
				@from = Date.today - 7
				@to = Date.today
			  when 'current_month'
				@from = Date.civil(Date.today.year, Date.today.month, 1)
				@to = (@from >> 1) - 1
			  when 'last_month'
				@from = Date.civil(Date.today.year, Date.today.month, 1) << 1
				@to = (@from >> 1) - 1
			  when '30_days'
				@from = Date.today - 30
				@to = Date.today
			  when 'current_year'
				@from = Date.civil(Date.today.year, 1, 1)
				@to = Date.civil(Date.today.year, 12, 31)
	        end
		elsif period_type == '2' || (period_type.nil? && (!fromdate.nil? || !todate.nil?))
		    begin; @from = fromdate.to_s.to_date unless fromdate.blank?; rescue; end
		    begin; @to = todate.to_s.to_date unless todate.blank?; rescue; end
		    @free_period = true
		else
		  # default
		  # 'current_month'		
			@from = Date.civil(Date.today.year, Date.today.month, 1)
			@to = (@from >> 1) - 1
	    end    
		
		@from, @to = @to, @from if @from && @to && @from > @to

  end
  
  def getLeaveAvailableHours
    available_hours = 0
    data = []
    userHours = WkUserLeave.leaveAvailableHours(params[:issue_id], params[:user_id]).first
    available_hours = userHours.balance + userHours.accrual - userHours.used  if userHours.present?
    data << { label: "Available" , hours: available_hours.to_s + " hours"}
    render :json => data
  end

end
