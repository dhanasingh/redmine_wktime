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

class WktimeController < WkbaseController


include WktimeHelper
include WkcrmHelper
require 'json'

before_action :require_login
before_action :check_perm_and_redirect, :only => [:edit, :update, :destroy] # user without edit permission can't destroy
before_action :check_editperm_redirect, :only => [:destroy]
before_action :check_view_redirect, :only => [:index]
before_action :check_log_time_redirect, :only => [:new]
before_action :check_module_permission, :only => [:index]

accept_api_auth :index, :edit, :update, :destroy, :delete_entries, :get_projects, :getissues, :getactivities, :get_api_users, :getclients, :get_issue_loggers

helper :custom_fields
helper :queries
include QueriesHelper
include ActionView::Helpers::TagHelper

	def index
		sort_init  [["start_date", "desc"], ["user_name", "asc"]]
		sort_update 'start_date' => "spent_on",
					'user_name' => "CONCAT(un.firstname,' ' ,un.lastname)",
					'hours' => "hours",
					'status' => "status",
					'modified_by' => "status_updater",
					'amount' => "amount"

		user_custom_fields = CustomField.where(['is_filter = ? AND type = ?', true, "UserCustomField"])
		@query = nil
		unless user_custom_fields.blank?
			@query = WkTimeEntryQuery.build_from_params(params, :project => nil, :name => '_')
		end
		set_filter_session
			retrieve_date_range
		@from = getStartDay(@from)
		@to = getEndDay(@to)
		user_id = session[controller_name].try(:[], :user_id)
		group_id = session[controller_name].try(:[], :group_id)
		status = session[controller_name].try(:[], :status)
		userfilter = getValidUserCF(session[controller_name].try(:[], :filters), user_custom_fields)

		unless userfilter.blank? || @query.blank?
			@query.filters = userfilter
		end
		set_user_projects
		if (!@manage_view_spenttime_projects.blank? && @manage_view_spenttime_projects.size > 0)
			@selected_project = getSelectedProject(@manage_view_spenttime_projects, false)
		end
		setMembers
		ids = nil
		if user_id.blank?
			user_id = (@currentUser_loggable_projects.blank? && @view_spenttime_projects.blank?) ? '-1' : User.current.id.to_s
			#user_id = @currentUser_loggable_projects.blank? ? '-1' : User.current.id.to_s
		end
		#if user_id.blank?
			#ids = is_member_of_any_project() ? User.current.id.to_s : '0'
		#	ids = User.current.id.to_s
		#elsif user_id.to_i == 0
		if user_id.to_i == 0
			unless @members.blank?
				@members.each_with_index do |users,i|
					if i == 0
						ids =  users[1].to_s
					else
						ids +=',' + users[1].to_s
					end
				end
			end
			ids = '0' if ids.nil?
			setUserIdsInSession(ids) #set user ids in session if "All User" is chosen
		else
			ids = user_id
		end
		if @from.blank? && @to.blank?
			getAllTimeRange(ids, true)
		end
		teQuery = getTEQuery(@from, @to, ids)
		queries = getQuery(teQuery, ids, @from, @to, status)
		orderStr =  + " ORDER BY " + sort_clause.join(",")

		respond_to do |format|
			format.html do
				findBySql(queries[0], queries[1], orderStr)
				render :layout => !request.xhr?
			end
			format.api do
				get_TE_entries(queries[0] + queries[1] + orderStr)
			end
			format.pdf do
				get_TE_entries(queries[0] + queries[1] + orderStr)
				findBySql(queries[0], queries[1], orderStr)
				send_data(list_to_pdf(@entries, setEntityLabel), :type => 'application/pdf', :filename => "#{setEntityLabel}.pdf")
			end
      format.csv do
				get_TE_entries(queries[0] + queries[1] + orderStr)
        headers = {cal_week: l(:label_week), date: l(:field_start_date), user: l(:field_user), type: getLabelforSpField, status: l(:field_status), modifiedby: l(:field_status_modified_by) }
				headers[:supervisor] = l(:label_ftte_supervisor) if isSupervisorApproval
        data = @entries.map do |e|
					status = e.status.present? ? statusString(e.status) : nil
					rowData = {cal_week: e.spent_on&.cweek, date: format_date(e.spent_on), user: e.user&.name, type: getUnit(e).to_s + (e.hours || e.amount || 0).round(2).to_s, status: status, modifiedby: e.status_updater}
					rowData[:supervisor] = e.user&.supervisor&.name if isSupervisorApproval
					rowData
				end
        send_data(csv_export(headers: headers, data: data), type: "text/csv; header=present", filename: "#{setEntityLabel}.csv")
      end
		end
	end

	def edit
		to = getEndDay(@startday)
		@prev_template = false
		@new_custom_field_values = getNewCustomField
		setup
		findWkTE(@startday)

		# Getting allowed Project members
		@users = []
		members = []
		projects = (@manage_projects || []).pluck(:id)
		projects.concat((@manage_others_log || []).pluck(:id))
		projects.each do |projID|
			project = Project.find(projID)
			project.members.each{|member| members << [member.user.name, member.user.id] }
		end
		members.each {|userID| @users << userID if userID && !@users.include?(userID) }
		if getSheetView == 'W'
			getUserwkStatuses
			getApproverPermProj
		end

		@editable = @wktime.nil? || @wktime.status == 'n' || @wktime.status == 'r'
		@editable = canSupervisorEdit if isSupervisorApproval && @editable && isSupervisor
		@locked  = isLocked(@startday)
		@editable = false if @locked
		set_edit_time_logs
		@entries = findEntries()
		if !$tempEntries.blank?
			newEntries = $tempEntries - @entries
			if !newEntries.blank?
				$tempEntries = $tempEntries - newEntries
				newEntries.each do |entry|
					entry.id = ""
					$tempEntries << entry
				end
			end
		end
		isError = params[:isError].blank? ? false : to_boolean(params[:isError])
		if (!$tempEntries.blank? && isError)
			@entries.each do |entry|
				if !entry.editable_by?(User.current) && !validateERPPermission('A_TE_PRVLG') && !isBilledTimeEntry(entry)
					$tempEntries << entry
				end
			end
			@entries = $tempEntries
		end
		set_project_issues(@entries)
		if @entries.blank? && params[:prev_template].present? && (Setting.plugin_redmine_wktime['wktime_previous_template_week']).to_i > 0
			@prev_entries = prevTemplate(@user.id)
			if !@prev_entries.blank?
				set_project_issues(@prev_entries)
				@prev_template = true
			end
		end
		respond_to do |format|
			format.html {
				render :layout => !request.xhr?
			}
			format.api
		end
	end

  # called when save is clicked on the page
	def update
		if api_request? && params.present?
			key = "wk_" + getTEName()
			params[key] = params
		end
		setup
		set_loggable_projects
		set_edit_time_logs
		@wktime = nil
		errorMsg = nil
		respMsg = nil
		wkattendance = nil
		findWkTE(@startday)
		@wktime = getWkEntity if @wktime.nil?
		allowApprove = false
		if getSheetView == 'W'
			getUserwkStatuses
			getApproverPermProj
		end
		if api_request?
			errorMsg = gatherAPIEntries
			errorMsg = validateMinMaxHr(@startday) if errorMsg.blank?
			total = @total
			allowApprove = true if check_approvable_status
		else
			total = params[:total].to_f
			gatherEntries
			allowApprove = true
		end
		#IssueLogs validation
		errorMsg = issueLogValidation if errorMsg.blank?

		errorMsg = gatherWkCustomFields(@wktime) if @wkvalidEntry && errorMsg.blank?
		wktimeParams = params[:wktime]
		cvParams = wktimeParams[:custom_field_values] unless wktimeParams.blank?
		useApprovalSystem = (!Setting.plugin_redmine_wktime['wktime_use_approval_system'].blank? &&
							Setting.plugin_redmine_wktime['wktime_use_approval_system'].to_i == 1)
		@wktime.transaction do
			begin
				if errorMsg.blank? && (!params[:wktime_save].blank? || !params[:wktime_save_continue].blank? ||
					(!params[:wktime_submit].blank? && @wkvalidEntry && useApprovalSystem))
					if !@wktime.nil? && ( @wktime.status == 'n' || @wktime.status == 'r')
						@wktime.status = :n
						# save each entry
						entrycount=0
						entrynilcount=0
						@entries.each do |entry|
							entrycount += 1
							entrynilcount += 1 if (entry.hours).blank?
							allowSave = true
							if (!entry.id.blank? && !entry.editable_by?(User.current))
								allowSave = false
							end
							allowSave = true if (to_boolean(@edittimelogs) || validateERPPermission('A_TE_PRVLG') || !isBilledTimeEntry(entry))
								if allowSave
									errorMsg = updateEntry(entry)
								else
									errorMsg = l(:error_not_permitted_save) if !api_request?
								end
								break unless errorMsg.blank?
						end
						if !params[:wktime_submit].blank? && useApprovalSystem
							@wktime.submitted_on = Date.today
							@wktime.submitter_id = User.current.id
							@wktime.status = :s
							if !Setting.plugin_redmine_wktime['wktime_uuto_approve'].blank? &&
								Setting.plugin_redmine_wktime['wktime_uuto_approve'].to_i == 1
								@wktime.status = :a
							end
						end
					end
					setTotal(@wktime,total)
					#if (errorMsg.blank? && total > 0.0)
					errorMsg = 	updateWktime if (errorMsg.blank? && ((!@entries.blank? && entrycount!=entrynilcount) || @teEntrydisabled))
				end

				if getSheetView == 'W' && (!params[:wktime_save].blank? || !params[:wktime_save_continue].blank? || !params[:wktime_submit].blank?)
					destroyWKstatuses(status='r', @userEntries)
				elsif useApprovalSystem && !params[:wktime_unapprove].blank?
					destroyWKstatuses(status='a', @approverEntries)
				end

				if !params[:wktime_approve].blank? || !params[:wktime_reject].blank? || !params[:hidden_wk_reject].blank?
					@approverEntries.each do | entry |
						next if entry.wkstatus.present?
						saveWKstatuses(entry)
					end
				elsif (!Setting.plugin_redmine_wktime['wktime_uuto_approve'].blank? &&
								Setting.plugin_redmine_wktime['wktime_uuto_approve'].to_i == 1 && !params[:wktime_submit].blank?)
					@userEntries.each do | entry |
						next if entry.wkstatus.present?
						saveWKstatuses(entry)
					end
				end

				if errorMsg.blank? && useApprovalSystem
					if !@wktime.nil? && @wktime.status == 's' || !params[:wktime_reject].blank? || !params[:hidden_wk_reject].blank?
						if !params[:wktime_approve].blank? && allowApprove && @userEntries.length == @approvedwkStatuses.length
							errorMsg = updateStatus(:a)
						elsif (!params[:wktime_reject].blank? || !params[:hidden_wk_reject].blank?) && allowApprove
							if api_request?
								teName = getTEName()
								if !params[:"wk_#{teName}"].blank? && !params[:"wk_#{teName}"][:notes].blank?
									@wktime.notes = params[:"wk_#{teName}"][:notes]
								end
							else
								@wktime.notes = params[:wktime_notes] unless params[:wktime_notes].blank?
							end
							errorMsg = updateStatus(:r)
							if email_delivery_enabled? && WkNotification.notify('timeRejected')
								sendRejectionEmail
							end
						elsif !params[:wktime_unsubmit].blank?
							errorMsg = updateStatus(:n)
						end
					elsif !params[:wktime_unapprove].blank? && !@wktime.nil? && @wktime.status == 'a' && allowApprove
						errorMsg = updateStatus(:s)
					elsif !params[:wktime_submit].blank? && !@wktime.nil? && ( @wktime.status == 'n' || @wktime.status == 'r')
						#if TE sheet is read only mode with submit button
						@wktime.submitted_on = Date.today
						@wktime.submitter_id = User.current.id
						if !Setting.plugin_redmine_wktime['wktime_uuto_approve'].blank? &&
							Setting.plugin_redmine_wktime['wktime_uuto_approve'].to_i == 1
							errorMsg = updateStatus(:a)
						else
							errorMsg = updateStatus(:s)
						end
					end
				end

			rescue Exception => e
				errorMsg = e.message
			end

			# Time exceeded notify trigger
			if errorMsg.blank? && params[:wktime_submit].present? && WkNotification.notify('timeExceeded')
				notify_time_exceeded(params[:startday], params[:user_id])
			end

			if errorMsg.blank?
				#when the are entries or it is not a save action
				if !@entries.blank? || !params[:wktime_approve].blank? ||
					(!params[:wktime_reject].blank? || !params[:hidden_wk_reject].blank?) ||
					!params[:wktime_unsubmit].blank? || !params[:wktime_unapprove].blank? ||
					((!params[:wktime_submit].blank? || !cvParams.blank?) && total > 0.0) # && @wkvalidEntry
					respMsg = l(:notice_successful_update)
				else
					respMsg = l(:error_wktime_save_nothing)
				end
			else
				respMsg = l(:error_te_save_failed, :label => setEntityLabel, :error => errorMsg)
				raise ActiveRecord::Rollback
			end
		end
		respond_to do |format|
		format.html {
			if errorMsg.blank?
				flash[:notice] = respMsg
				$tempEntries = nil
				if params[:wktime_save_continue]
					startday = !@entries.present? ? @startday  : @startday+ @renderer.getDaysPerSheet
					redirect_to action: 'edit' , startday: startday, user_id: @user.id, project_id: params[:project_id], sheet_view: getSheetView
				else
					redirect_to :action => 'index' , :tab => params[:tab]
				end
			else
				flash[:error] = respMsg
				$tempEntries = @entries
				if !params[:enter_issue_id].blank? && params[:enter_issue_id].to_i == 1
					redirect_to :action => 'edit', :user_id => params[:user_id], :startday => @startday, :isError => true, :enter_issue_id => 1
				else
					redirect_to action: 'edit', user_id: params[:user_id], startday: @startday,sheet_view: getSheetView, project_id: @projectId, isError: true
				end
			end
		}
		format.api{
			if errorMsg.blank?
				render :plain => respMsg, :layout => nil
			else
				@error_messages = respMsg.split('\n')
				render :template => 'common/error_messages', :format => [:api], :status => :unprocessable_entity, :layout => nil
			end
			}
		end
	end

	def deleterow
		if check_editPermission
			if api_request?
				ids = gatherIDs
			else
				ids = params['ids']
			end
			delete(ids)
			respond_to do |format|
				format.text  {
					render :plain => 'OK'
				}
				format.api {
					render_api_ok
				}
			end
		else
			respond_to do |format|
				format.text  {
					render :plain => 'FAILED'
				}
				format.api {
					render_403
				}
			end
		end
	end

	# API
	def delete_entries
		deleterow
	end

	def gatherIDs
		ids = Array.new
		teName = getTEName()
		entityNames = getEntityNames()
		entries = JSON.parse(params["#{entityNames[1]}"])
		if !entries.blank?
			entries.each do |entry|
				ids << entry["id"]
			end
		end
		ids
	end

	def destroy
		setup
		#cond = getCondition('spent_on', @user.id, @startday, @startday+6)
		#TimeEntry.delete_all(cond)
		#below two lines are hook code for lock TE
		#hookPerm = call_hook(:controller_check_locked, {:startdate => @startday})
		#locked = hookPerm.blank? ? false : hookPerm[0]
		locked  = isLocked(@startday)
		findWkTE(@startday)
		if locked
			flash[:error] = l(:error_time_entry_delete)
			redirect_to :action => 'index' , :tab => params[:tab]
		else
			deletable = @wktime.nil? || @wktime.status == 'n' || @wktime.status == 'r'
			if deletable
				@entries = findEntries()
				@entries.each do |entry|
					entry.destroy()
				end
				cond = getCondition('begin_date', @user.id, @startday)
				deleteWkEntity(cond)
			end
			respond_to do |format|
				format.html {
					flash[:notice] = l(:notice_successful_delete)
					redirect_back_or_default :action => 'index', :tab => params[:tab]
				}
				format.api  {
					if deletable
						render_api_ok
					else
						render_403
					end
				}
			end
		end
	end

	def getIssueAssignToUsrCond
		issueAssignToUsrCond=nil
		user_id = params[:user_id] || User.current.id
		groupIDs = Wktime.getUserGrp(user_id).join(',')
		if (!Setting.plugin_redmine_wktime['wktime_allow_filter_issue'].blank? && Setting.plugin_redmine_wktime['wktime_allow_filter_issue'].to_i == 1)
			assignedCnd = groupIDs.present? ? "OR #{Issue.table_name}.assigned_to_id in (#{groupIDs})" : ''
			issueAssignToUsrCond ="and (#{Issue.table_name}.assigned_to_id=#{user_id} #{assignedCnd} OR #{Issue.table_name}.author_id=#{user_id})"
		end
		issueAssignToUsrCond
	end

	def getissues
		projectids = []
		if !params[:term].blank?
			 subjectPart = (params[:term]).to_s.strip
			set_loggable_projects
			@logtime_projects.each do |project|
				projectids << project.id
			end
		end
		issueAssignToUsrCond = getIssueAssignToUsrCond
		trackerIDCond=nil
		trackerid=nil
		#If click add row or project changed, tracker list does not show, get tracker value from settings page
		if (params[:tracker_id].blank? || !params[:term].blank?)
			params[:tracker_id] = Setting.plugin_redmine_wktime[getTFSettingName()]
			params[:tracker_id].reject! {|id| id.to_s == "0" } if params[:tracker_id].present?
			trackerIDCond= "AND #{Issue.table_name}.tracker_id in(#{(Setting.plugin_redmine_wktime[getTFSettingName()]).join(',')})" if !params[:tracker_id].blank? && params[:tracker_id] != ["0"]
		else
			params[:tracker_id] = params[:tracker_id].split(' ') if params[:tracker_id].present?
		end
		if Setting.plugin_redmine_wktime['wktime_closed_issue_ind'].to_i == 1
			if !params[:tracker_id].blank? && params[:tracker_id] != ["0"] && params[:term].blank?
				projIds = "#{(params[:project_id] || (!params[:project_ids].blank? ? params[:project_ids].join(",") : ''))}"
				projCond = !projIds.blank? ? "AND #{Issue.table_name}.project_id in (#{projIds})" : ""
				issues = Issue.where(["(#{Issue.table_name}.tracker_id in ( ?) #{issueAssignToUsrCond}) #{projCond}", params[:tracker_id]]).order('project_id')
			elsif !params[:term].blank?
					projIds = "#{(params[:project_id] || (!params[:project_ids].blank? ? params[:project_ids].join(",") : '') || projectids)}"
					projCond = !projIds.blank? ? "AND #{Issue.table_name}.project_id in (#{projIds})" : ""
					if subjectPart.present?
						if subjectPart.match(/^\d+$/)
							cond = ["((LOWER(#{Issue.table_name}.subject) LIKE ? OR #{Issue.table_name}.id=?) #{issueAssignToUsrCond} #{trackerIDCond}) #{projCond}", "%#{subjectPart.downcase}%","#{subjectPart.to_i}"]
						else
							cond = ["(LOWER(#{Issue.table_name}.subject) LIKE ? #{issueAssignToUsrCond} #{trackerIDCond}) #{projCond}", "%#{subjectPart.downcase}%"]
						end
						issues = Issue.where(cond).order('project_id')
					end
			else
				if (!Setting.plugin_redmine_wktime['wktime_allow_filter_issue'].blank? && Setting.plugin_redmine_wktime['wktime_allow_filter_issue'].to_i == 1)
					user_id = params[:user_id] || User.current.id
					groupIDs = Wktime.getUserGrp(user_id).join(',')
					projIds = "#{(params[:project_id] || (!params[:project_ids].blank? ? params[:project_ids].join(",") : '') || projectids)}"
					projCond = !projIds.blank? ? "AND #{Issue.table_name}.project_id in (#{projIds})" : ""
					assignedCnd = groupIDs.present? ? "OR #{Issue.table_name}.assigned_to_id in (#{groupIDs})" : ''
					issues = Issue.where(["((#{Issue.table_name}.assigned_to_id= ? #{assignedCnd} OR #{Issue.table_name}.author_id= ?) #{trackerIDCond}) #{projCond}", params[:user_id], params[:user_id]]).order('project_id')
				else
					issues = Issue.order('project_id')
					issues = issues.where(:project_id => params[:project_id] || params[:project_ids]) if params[:project_id].present? ||  params[:project_ids].present?
				end
			end
		else
			@startday = params[:startday].to_s.to_date
			projIds = "#{(params[:project_id] || (!params[:project_ids].blank? ? params[:project_ids].join(",") : '') || projectids)}"
			projCond = !projIds.blank? ? "AND #{Issue.table_name}.project_id in (#{projIds})" : ""
			if !params[:tracker_id].blank? && params[:tracker_id] != ["0"]	&& params[:term].blank?
				cond = ["((#{IssueStatus.table_name}.is_closed = ? OR #{Issue.table_name}.closed_on >= ?) AND  #{Issue.table_name}.tracker_id in ( ?) #{issueAssignToUsrCond}) #{projCond}", false, @startday,params[:tracker_id]]
			elsif !params[:term].blank?
				if subjectPart.present?
					if subjectPart.match(/^\d+$/)
						cond = ["((LOWER(#{Issue.table_name}.subject) LIKE ? OR #{Issue.table_name}.id=?)  AND (#{IssueStatus.table_name}.is_closed = ? OR #{Issue.table_name}.closed_on >= ?) #{issueAssignToUsrCond} #{trackerIDCond}) #{projCond}", "%#{subjectPart.downcase}%","#{subjectPart.to_i}", false, @startday]
					else
						cond = ["((LOWER(#{Issue.table_name}.subject) LIKE ?  AND (#{IssueStatus.table_name}.is_closed = ? OR #{Issue.table_name}.closed_on >= ?)) #{issueAssignToUsrCond} #{trackerIDCond}) #{projCond}", "%#{subjectPart.downcase}%", false, @startday]
					end
				 end
			else
				cond =["((#{IssueStatus.table_name}.is_closed = ? OR #{Issue.table_name}.closed_on >= ?) #{issueAssignToUsrCond} #{trackerIDCond}) #{projCond}", false, @startday]
			end

			issues = Issue.includes(:status).references(:status).where(cond).order('project_id')
		end
		#issues.compact!
		user = params[:user_id].present? ? User.find(params[:user_id]) : User.current
		if (!Setting.plugin_redmine_wktime['wktime_allow_filter_issue'].blank? && Setting.plugin_redmine_wktime['wktime_allow_filter_issue'].to_i == 1)
			# adding additional assignee
			userIssues = getGrpUserIssues(params)
			issues = userIssues.present? ? (issues + userIssues).uniq : issues
		end

		if !params[:autocomplete]
			respond_to do |format|
				issues = issues.select(&:present?)
				format.any(:html, :text) do
					issStr =""
					issues.each do |issue|
					issStr << issue.project_id.to_s() + '|' + issue.id.to_s() + '|' + issue.tracker.to_s() +  '|' +
						issue.subject  + "\n" if issue.visible?(user)
					end
					render :plain => issStr
				end
				format.json do
					render :json => formatIssue(issues, user)
				end
			end
		else
			if params[:format] != "json"
				subject = params[:q].present? ? "%"+(params[:q]).downcase+"%" : ""
				issues = issues.where("subject like ? OR issues.id = ?", subject, params[:q].to_i) if params[:q].present?
				issueRlt = (+"").html_safe
				issues.each do |issue|
					issueRlt << content_tag("span", "#"+issue.id.to_s+": "+issue.subject, class: "issue_select", id: issue.id ) if issue.visible?(user) && showIssueLogger(issue.project)
				end
				issueRlt = content_tag("span", l(:label_no_data)) if issueRlt.blank?
				issueRlt = "$('#issueLog .drdn-items.issues').html('" + issueRlt + "');"
				render js: issueRlt
			else
				render :json => formatIssue(issues, user)
			end
		end
	end

	def formatIssue(issues, user)
		issStr=[]
		issues.each do |issue|
			issStr << {:value => issue.id.to_s(), :label => issue.tracker.to_s() +  " #" + issue.id.to_s() + ": " + issue.subject }  if issue.visible?(user)
		end
		issStr
	end

	def get_issue_loggers(valid=false)
		if params[:type] == "finish" || valid
			issueLogs = WkSpentFor.getIssueLog
			if valid
				startday = params[:startday].to_date
				issueLogs = issueLogs.where("TE.spent_on between ? AND ?", startday, startday +6.days)
				return issueLogs
			else
				respond_to do |format|
					format.any(:html, :text) do
						container = ""
						timer = ""
						issueLogs.each do |log|
							dateTime = get_current_DateTime
							hours = time_diff(dateTime, log.spent_on_time)
							timespan = content_tag("span", hours.to_s, id: ("timer_" + log.id.to_s))
							issuespan = content_tag("span", "#{log.project_name} - #{log.tracker_name} - #{log.issue_id}##{log.subject} " )
							button = content_tag("span", "Stop", class: "issue_select", id: log.id,
								style: "color: white; font-weight: bold; border-radius: 20px; background: red; padding-left: 10px; padding-top: 3px; padding-bottom: 3px; padding-right: 10px; margin-left: 5px; cursor: pointer;" )
							container << content_tag("span", (issuespan + timespan + button))
							timer << "$('##{("timer_" + log.id.to_s)}').timer({ action: 'start', seconds: #{(dateTime - log.spent_on_time).to_i} });"
						end
						container = "$('#issueLog .drdn-items.issues').html('" + container + "').css('cursor', 'default');" + timer
						render(js: container)
					end
					format.json do
						# issues = issueLogs.map{|i| i.to_h}
						render json: issueLogs
					end
				end
			end
		else
			getissues
		end
	end

	def getactivities
		project = nil
		error = nil
		project_id = params[:project_id]
		if !project_id.blank?
			project = Project.find(project_id)
		elsif !params[:issue_id].blank?
			issue = Issue.find(params[:issue_id])
			project = issue.project
			project_id = project.id
			u_id = params[:user_id]
			user = User.find(u_id)
			if !user_allowed_to?(:log_time, project)
				error = "403"
			end
		else
			error = "403"
		end

		if error.blank?
			if params[:format].present?
				actStr =""
				project.activities.each do |a|
				actStr << project_id.to_s() + '|' + a.id.to_s() + '|' + a.is_default.to_s() + '|' + a.name + "\n"
				end
				respond_to do |format|
					format.text  {
						render :plain => actStr
				}
				end
			else
				activities = []
				activities = project.activities.map { |act| { value: act.id, label: act.name }}
				render json: activities
			end
		else
			render_403
		end
	end

	def getclients
		project = nil
		error = nil
		teUser = User.find(params[:user_id])
		project_id = params[:project_id]
		if !project_id.blank?
			project = Project.find(project_id)
		elsif !params[:issue_id].blank?
			issue = Issue.find(params[:issue_id])
			project = issue.project
			project_id = project.id
			u_id = params[:user_id]
			user = User.find(u_id)
			if !user_allowed_to?(:log_time, project)
				error = "403"
			end
		else
			error = "403"
		end
		usrLocationId = teUser.wk_user.blank? ? nil : teUser.wk_user.location_id
		project = project.account_projects.includes(:parent).order(:parent_type) unless project.blank?

		respond_to do |format|
			format.text  {
				clientStr =""
				unless project.blank?
					project.each do |ap|
						clientStr << project_id.to_s() + '|' + ap.parent_type + '_' + ap.parent_id.to_s() + '|' + "" + (params[:separator].blank? ? '|' : params[:separator] ) + ap.parent.name + "\n"  #if ap.parent.location_id == usrLocationId
					end
				end
				render plain: clientStr
			}
			format.json  {
				spentFors = []
				project.each{ |client|
					spentFors << {
						value: project_id.to_s() + '|' + client.parent_type + '_' + client.parent_id.to_s() + '|',
						label: client.parent.name
					} #if client.parent.location_id == usrLocationId
				} if project.present?
				render(json: spentFors)
			}
		end
	end

	def getuserclients
		error = nil
		teUser = User.find(params[:user_id])
		userClients = getClientsByUser(teUser.id, false)
		clientStr =""
		usrLocationId = teUser.wk_user.blank? ? nil : teUser.wk_user.location_id
		userClients.each do |ap|
			clientStr << ap[1].to_s + ',' + ap[0].to_s + "\n"
		end

		respond_to do |format|
			format.text  {
			if error.blank?
				render :plain => clientStr
			else
				render_403
			end
			}
		end
	end

	def getClientsByUser(userId, needBlank)
		set_loggable_projects
		set_managed_projects
		userProjects = @logtime_projects.blank? ? @manage_projects : @logtime_projects
		userProjects = @logtime_projects & @manage_projects if !@manage_projects.blank? && !@logtime_projects.blank?
		projectids = Array.new
		user = User.find(userId)
		billableClients = Array.new
		# usrLocationId = user.wk_user.blank? ? nil : user.wk_user.location_id
		unless userProjects.blank?
			userProjects.each do |project|
				projectids << project.id
			end
		end
		usrBillableProjects = WkAccountProject.includes(:parent).where(:project_id => projectids)
		# locationBillProject = usrBillableProjects.select {|bp| bp.parent.location_id == usrLocationId}
		locationBillProject = usrBillableProjects.sort_by{|parent_type| parent_type}
		billableClients = locationBillProject.collect {|billProj| [billProj&.parent&.name, billProj.parent_type.to_s + '_' + billProj.parent_id.to_s]}
		billableClients.unshift(["", ""]) if needBlank
		billableClients = billableClients.uniq
		billableClients
	end

	def getuserissues
		error = nil
		teUser = User.find(params[:user_id])
		userIssues = getIssuesByUser(teUser.id, false)
		clientStr = ""
		usrLocationId = teUser.wk_user.blank? ? nil : teUser.wk_user.location_id
		userIssues.each do |issue|
			clientStr << issue[1].to_s + ',' + issue[0].to_s + "\n"
		end

		respond_to do |format|
			format.text  { render :plain => clientStr }
		end
	end

	def getIssuesByUser(userId, needBlank)
		set_loggable_projects
		set_managed_projects
		userProjects = @logtime_projects.blank? ? @manage_projects : @logtime_projects
		userProjects = @logtime_projects & @manage_projects if !@manage_projects.blank? && !@logtime_projects.blank?
		projectids = Array.new
		assignedIssues = Array.new
		user = User.find(userId)
		usrLocationId = user.wk_user.blank? ? nil : user.wk_user.location_id
		unless userProjects.blank?
			userProjects.each do |project|
				projectids << project.id
			end
		end
		#userIssues = Issue.includes(:project).joins("INNER JOIN custom_values cv on cv.customized_type = 'Issue' and cv.customized_id = issues.id and cv.custom_field_id = #{getSettingCfId('wktime_additional_assignee')} AND (cv.value = '#{userId}' OR issues.assigned_to_id = #{userId})")

		#userIssues = Issue.includes(:project).joins("INNER JOIN wk_issue_assignees ia on ((ia.issue_id = issues.id and ia.user_id = #{userId}) OR issues.assigned_to_id = #{userId})")

		userIssues = WkIssueAssignee.joins(:issue)
		userIssues = userIssues.includes(:project).where("wk_issue_assignees.user_id = #{userId} ")
		assignedIssueUser = Issue.includes(:project).where(:assigned_to_id => userId)
		issueAssignee = userIssues + assignedIssueUser
		issueAssignee = issueAssignee.uniq
		issueAssignee = issueAssignee.sort_by{|subject| subject}
		assignedIssues = issueAssignee.collect {|issue| [issue.project.name + " #" + issue.id.to_s + ": " + issue.subject, issue.id]}
		assignedIssues.unshift( ["", ""]) if needBlank
		assignedIssues
	end

	def getusers
		projmembers = getProjMembers()
		userStr = ""
		if !projmembers.nil?
			projmembers.each do |m|
				userStr << m.user_id.to_s() + ',' + m.name + "\n"
			end
		end
		respond_to do |format|
			format.text  { render :plain => userStr }
		end
	end

	def getProjMembers
		project = Project.find(params[:project_id])
		userStr = ""
		# userList = call_hook(:controller_project_member, {:project_id => params[:project_id], :page => params[:page]})
		if isSupervisorApproval #!userList.blank?
			projmembers = getSupervisorMembers(params[:project_id], params[:page]) #userList[0].blank? ? nil : userList[0]
		else
			projmembers = project.members.order("#{User.table_name}.firstname ASC,#{User.table_name}.lastname ASC")
		end
		if !projmembers.nil?
			projmembers = projmembers.to_a.uniq
		end
		return projmembers
	end

  # Export wktime to a single pdf file
  def export
    respond_to do |format|
		@new_custom_field_values = getNewCustomField
		@entries = findEntries()
		findWkTE(@startday)
		unitLabel = getUnitLabel
		format.pdf {
			send_data(wktime_to_pdf(@entries, @user, @startday,unitLabel), :type => 'application/pdf', :filename => "#{@startday}-#{params[:user_id]}.pdf")
		}
		format.csv {
			send_data(wktime_to_csv(@entries, @user, @startday,unitLabel), :type => 'text/csv', :filename => "#{@startday}-#{params[:user_id]}.csv")
      }
    end
  end

	def getLabelforSpField
		l(:field_hours)
	end

  def getCFInRowHeaderHTML
    "wktime_cf_in_row_header"
  end

  def getCFInRowHTML
    "wktime_cf_in_row"
  end

	def getTFSettingName
		"wktime_issues_filter_tracker"
	end

	def showSpentFor
		true
	end

	def getUnit(entry)
		nil
	end

	def getUnitDDHTML
		nil
	end

	def getUnitLabel
		nil
	end

	def showWorktimeHeader
		(!Setting.plugin_redmine_wktime['wktime_work_time_header'].blank? &&
		Setting.plugin_redmine_wktime['wktime_work_time_header'].to_i == 1) && (!Setting.plugin_redmine_wktime['wktime_enable_clock_in_out'].blank? &&
		Setting.plugin_redmine_wktime['wktime_enable_clock_in_out'].to_i == 1) && (!Setting.plugin_redmine_wktime['wktime_enable_attendance_module'].blank? && Setting.plugin_redmine_wktime['wktime_enable_attendance_module'].to_i == 1 )
	end

	def enterCommentInRow
		!Setting.plugin_redmine_wktime['wktime_enter_comment_in_row'].blank? &&
		Setting.plugin_redmine_wktime['wktime_enter_comment_in_row'].to_i == 1
	end

	def enterCustomFieldInRow(row)
		entry = nil
		custom_field_values = entry.nil? ? @new_custom_field_values : entry.custom_field_values
		cf_value = nil
		if row.to_i == 1
			!Setting.plugin_redmine_wktime['wktime_enter_cf_in_row1'].blank? &&
			(cf_value = custom_field_values.detect { |cfv|
				cfv.custom_field.id == Setting.plugin_redmine_wktime['wktime_enter_cf_in_row1'].to_i }) != nil
		else
			!Setting.plugin_redmine_wktime['wktime_enter_cf_in_row2'].blank? &&
			(cf_value = custom_field_values.detect { |cfv|
				cfv.custom_field.id == Setting.plugin_redmine_wktime['wktime_enter_cf_in_row2'].to_i }) != nil
		end
	end

	def maxHour
		Setting.plugin_redmine_wktime['wktime_max_hour_day'].blank? ? 0 : Setting.plugin_redmine_wktime['wktime_max_hour_day']
	end

	def minHour
		Setting.plugin_redmine_wktime['wktime_min_hour_day'].blank? ? 0 : Setting.plugin_redmine_wktime['wktime_min_hour_day']
	end

	def total_all(total)
		html_hours(l_hours(total))
	end

	 def get_status
		if !params[:startDate].blank?
			status = getTimeEntryStatus(params[:startDate].to_date,params[:user_id])
		else
			status = nil
		end
		respond_to do |format|
			format.text  { render :plain => status }
		end
	end

	def setLimitAndOffset
		if api_request?
			@offset, @limit = api_offset_and_limit
			if !params[:limit].blank?
				@limit = params[:limit]
			end
			if !params[:offset].blank?
				@offset = params[:offset]
			end
		else
			@entry_pages = Paginator.new @entry_count, per_page_option, params['page']
			@limit = @entry_pages.per_page
			@offset = @entry_pages.offset
		end
	end

	def get_membersby_group
		group_by_users=""
		getGroupUsers.each do |users|
			group_by_users << users.id.to_s() + ',' + users.name + "\n"
		end
		respond_to do |format|
			format.text  { render :plain => group_by_users }
		end
	end

	def getGroupUsers
		userList=[]
		set_managed_projects
		userList = getGrpMembers
		return userList
	end

	def check_approvable_status
		te_projects=[]
		ret = false
		if !@entries.blank?
			@te_projects = @entries.collect{|entry| entry.project}.uniq
			te_projects = @approvable_projects & @te_projects if !@te_projects.blank?
		end

		if isSupervisorApproval #!hookPerm.blank?
			ret = isSupervisor #hookPerm[0]
		end
		ret = true if validateERPPermission('A_TE_PRVLG')
		ret = ((ret || !te_projects.blank?) && (@user.id != User.current.id || (!Setting.plugin_redmine_wktime['wktime_own_approval'].blank? &&
							Setting.plugin_redmine_wktime['wktime_own_approval'].to_i == 1 )))? true: false

		ret
	end

	def testapi
		respond_to do |format|
			format.html {
				render :layout => !request.xhr?
			}
		end
	end

	def textfield_size
		4
	end

	def get_tracker
		ret = false;
		tracker = get_trackerbyIssue(params[:issue_id])
		settingstracker = Setting.plugin_redmine_wktime[getTFSettingName()]
		if settingstracker != ["0"]
			if ((settingstracker.include?("#{tracker}")) || (tracker == '0'))
				ret = true
			end
		else
			ret = true
		end

		respond_to do |format|
			format.text  { render :plain => ret }
		end
	end

	def send_sub_reminder_email
		userList = ""
		weekHash = Hash.new
		userHash = Hash.new
		mngrHash = Hash.new
		respMsg = "OK"
		allowedStatus = ['e','r','n'];
		pStatus = get_statusFromSession #params[:status].split(',')
		status = pStatus.blank? ? allowedStatus : (allowedStatus & pStatus)
		wkentries = nil
		if !status.blank?
			ids = getUserIds
			setUserCFQuery
			label_te = getTELabel
			teQuery = getTEQuery(params[:from].to_date, params[:to].to_date, ids)
			queries = getQuery(teQuery, ids, params[:from].to_date, params[:to].to_date, status) #['e','r','n']

			wkentries = findTEEntryBySql(queries[0]+queries[1])
			wkentries.each do |entries|
				user = entries.user
				if !userHash.has_key?(user.id)
					userHash[user.id] = user
					weekHash[user.id] = [entries.spent_on]
					hookMgr = call_hook(:controller_get_manager, {:user => user, :approver => false})
					mngrArr = hookMgr.blank? ? nil : hookMgr[0]
					mngrHash[user.id] = mngrArr
				else
					weekArr = weekHash[user.id]
					weekHash[user.id] = weekArr << entries.spent_on
				end
			end
			userHash.each_key do |key|
				user = userHash[key]
				errMsg = ""
				if WkNotification.notify('nonSubmission')
					weekHash[key].each do |date|
						model = Wktime.where('begin_date = ? AND user_id = ?', date, user.id).first
						WkUserNotification.userNotification(user.id, model, 'nonSubmission') if model.present?
					end
				end
				begin
					WkMailer.submissionReminder(user, mngrHash[key], weekHash[key], params[:email_notes], label_te).deliver
				rescue Exception => e
					errMsg = e.message
				end
				userList += user.name + "\n" if errMsg.blank?
			end
			WkMailer.sendConfirmationMail(userList, true, label_te).deliver if !userList.blank?
		end
		respMsg = l(:text_wk_no_reminder) if (wkentries.blank? || (!wkentries.blank? && wkentries.size == 0))
		respond_to do |format|
			format.text  { render :plain => respMsg }
		end
	end

	def send_appr_reminder_email
		mgrList = ""
		userHash = Hash.new
		mgrHash = Hash.new
		respMsg = "OK"
		allowedStatus = ['s'];
		pStatus = get_statusFromSession
		status = pStatus.blank? ? allowedStatus : (allowedStatus & pStatus)
		users = nil
		if !status.blank?
			entityNames = getEntityNames
			ids = getUserIds
			setUserCFQuery
			label_te = getTELabel
			user_cf_sql = @query.user_cf_statement('u') if !@query.blank?
			queryStr = "select distinct u.*, w.id AS wktime_id from users u " +
						"left outer join #{entityNames[0]} w on u.id = w.user_id "+ get_comp_condition('w') +
						"and (w.begin_date between '#{params[:from]}' and '#{params[:to]}') " #+
						#"where u.id in (#{ids}) and w.status = 's'"
			queryStr += " #{user_cf_sql} " if !user_cf_sql.blank?
			queryStr += (!user_cf_sql.blank? ? " AND " : " WHERE ") + " u.id in (#{ids}) and w.status = 's' "
			users = User.find_by_sql(queryStr)
			users.each do |user|
				mngrArr = getManager(user, true)
				if !mngrArr.blank?
					mngrArr.each do |m|
						userArr = []
						if mgrHash.has_key?(m.id)
							userArr = userHash[m.id]
							userHash[m.id] = userArr << user
						else
							mgrHash[m.id] = m
							userHash[m.id] = [user]
						end
					end
				end
			end
			if !mgrHash.blank?
				mgrHash.each_key do |key|
					userList = []
					subOrd = userHash[key]
					subOrd.each do |user|
						userList << user.name
					end
					errMsg = ""
					begin
						if WkNotification.notify('timeApproved')
							users.pluck(:wktime_id).each do |id|
								WkUserNotification.userNotification(mgrHash[key].id, Wktime.where(id: id).first, 'timeApproved')
							end
						end
						WkMailer.approvalReminder(mgrHash[key], userList.uniq.join("\n"), params[:email_notes], label_te).deliver
					rescue Exception => e
						errMsg = e.message
					end
					mgrList += mgrHash[key].name + "\n" if errMsg.blank?
				end
				WkMailer.sendConfirmationMail(mgrList, false, label_te).deliver if !mgrList.blank?
			end
		end
		respMsg = l(:text_wk_no_reminder) if (users.blank? || (!users.blank? && users.size == 0))
		respond_to do |format|
			format.text  { render :plain => respMsg }
		end
	end

	def update_attendance
		paramvalues = Array.new
		entryvalues = Array.new
		ret = ""
		count = 0
		oldendvalue = ""
		paramvalues = params[:editvalue].split(',')
		if (params[:nightshift] == "false")
			count = 1
		end
		for i in 0..paramvalues.length-1
			entryvalues = paramvalues[i].split('|')
			begin
			if !entryvalues[0].blank? #&& isAccountUser
				wkattendance =  WkAttendance.find(entryvalues[0])
				entrydate = wkattendance.start_time
				start_local = entrydate.localtime
				starttime = start_local.change({ hour: entryvalues[1].to_time.strftime("%H").to_i, min: entryvalues[1].to_time.strftime("%M").to_i, sec: entryvalues[1].to_time.strftime("%S").to_i })
				oldendvalue = entryvalues[2]
				if (params[:nightshift] == "true")
					entryvalues[2] = "23:59"
				end
				if !entryvalues[2].blank?
					endtime = start_local.change({ hour: entryvalues[2].to_time.strftime("%H").to_i, min: entryvalues[2].to_time.strftime("%M").to_i, sec: entryvalues[2].to_time.strftime("%S").to_i })
				end
				wkattendance.start_time = starttime
				wkattendance.end_time = endtime
				wkattendance.hours = computeWorkedHours(starttime, endtime, true)#entryvalues[3]
				entryvalues[0] = params[:nightshift] ? '' : entryvalues[0]
			else
				wkattendance = WkAttendance.new
				@startday = Date.parse params[:startdate]
				if(params[:nightshift] == "true")
					entryvalues[1] = entryvalues[5]
					entryvalues[2] = "00:00"
					entryvalues[3] = oldendvalue
				end
				entrydate = @startday  +  ((entryvalues[1].to_i)- 1) #to_boolean(params[:isdate]) ? params[:startdate] : @startday  +  ((entryvalues[1].to_i)- 1)
				wkattendance.user_id = params[:user_id].to_i
				wkattendance.start_time = !entryvalues[2].blank? ? Time.parse("#{entrydate.to_s} #{ entryvalues[2].to_s}:00 ").localtime.to_s : '00:00'
				if !entryvalues[3].blank?
					wkattendance.end_time = Time.parse("#{entrydate.to_s} #{ entryvalues[3].to_s}:00 ").localtime.to_s
					wkattendance.hours = computeWorkedHours(wkattendance.start_time , wkattendance.end_time, true)#entryvalues[4]
				end
				ret += '|'
				ret += entryvalues[1].to_s
				ret += ','
				count = 1
			end
			#wkattendance.save()
			if(((wkattendance.start_time.localtime).to_formatted_s(:time)).to_s == "00:00" && ((wkattendance.end_time.localtime).to_formatted_s(:time)).to_s == "00:00" && wkattendance.id != nil)
				wkattendance.destroy()
			else
				wkattendance.save()
			end
			end until count == 1
			ret += wkattendance.id.to_s
			ret += ','
			ret += ((wkattendance.start_time.localtime).to_formatted_s(:time)).to_s
			ret += ','
			ret += !((wkattendance.end_time)).blank? ?  ((wkattendance.end_time.localtime).to_formatted_s(:time)).to_s : '00:00'
		end
		respond_to do |format|
			format.text  { render :plain => ret }
		end
	end

	def findAttnEntries
		dateStr = getConvertDateStr('start_time')
		WkAttendance.where(" user_id = '#{params[:user_id]}' and #{dateStr} between '#{@startday}'  and '#{@startday + 6}' ").order("start_time")
	end

	def getTotalBreakTime
		breakTimes = Setting.plugin_redmine_wktime['wktime_break_time']
		totalBT = 0
		if !breakTimes.blank?
			breakTimes.each do |bt|
				from_hr = bt.split('|')[0].strip
				from_min = bt.split('|')[1].strip
				to_hr = bt.split('|')[2].strip
				to_min = bt.split('|')[3].strip
				totalBT += (to_hr.to_i * 60 + to_min.to_i ) - (from_hr.to_i * 60 + from_min.to_i )
			end
		end
		if totalBT > 0
			totalBT = (totalBT/60.0)
		end
		totalBT
	end

	def time_rpt
		@user = (session[:wkreport].try(:[], :user_id).blank? || (session[:wkreport].try(:[], :user_id)).to_i < 1) ? User.current : User.find(session[:wkreport].try(:[], :user_id))
		@startday = getStartDay((session[:wkreport][:from]).to_s.to_date)
		render :action => 'time_rpt', :layout => false
	end

		############ Moved from private ##############

	def findEntries
		setup
		cond = getCondition('spent_on', @user.id, @startday, @startday+6)
		findEntriesByCond(cond)
	end

	def getNewCustomField
		TimeEntry.new.custom_field_values
	end

	def getTELabel
		l(:label_wk_timesheet)
	end

	def getUserwkStatuses
		cond = getCondition('spent_on', @user.id, @startday, @startday+6)
		@userEntries = findEntriesByCond(cond)
		@approvedwkStatuses = @userEntries.joins("LEFT JOIN wk_statuses ON time_entries.id = wk_statuses.status_for_id" + get_comp_condition('wk_statuses') ).where("status_for_type='TimeEntry' and wk_statuses.status = 'a'").select("time_entries.*")
	end

	def getApproverPermProj
		@approverEntries = []
		@approverwkStatuses = []
		approvableProj = @approvable_projects.pluck(:id).join(',')
		if approvableProj.present?
			cond = "spent_on BETWEEN '#{@startday}' AND '#{@startday+6}' AND user_id = #{@user.id} AND time_entries.project_id IN (#{approvableProj})"
			@approverEntries = findEntriesByCond(cond)
			@approverwkStatuses = @approverEntries.joins("LEFT JOIN wk_statuses ON time_entries.id = wk_statuses.status_for_id" + get_comp_condition('wk_statuses') ).where("status_for_type='TimeEntry' and wk_statuses.status = 'a'").select("time_entries.*")
		end
	end

	############ Moved from private ##############

	def showClockInOut
		(!Setting.plugin_redmine_wktime['wktime_enable_clock_in_out'].blank? &&
		Setting.plugin_redmine_wktime['wktime_enable_clock_in_out'].to_i == 1) && (!Setting.plugin_redmine_wktime['wktime_enable_attendance_module'].blank? && Setting.plugin_redmine_wktime['wktime_enable_attendance_module'].to_i == 1 ) && showWorktimeHeader
	end

	def maxHourPerWeek
		Setting.plugin_redmine_wktime['wktime_max_hour_week'].blank? ? 0 : Setting.plugin_redmine_wktime['wktime_max_hour_week']
	end

	def minHourPerWeek
		Setting.plugin_redmine_wktime['wktime_min_hour_week'].blank? ? 0 : Setting.plugin_redmine_wktime['wktime_min_hour_week']
	end

	def lockte
		@lock = WkTeLock.order(id: :desc)
		render :action => 'lockte'
	end

	 def lockupdate
		telock = WkTeLock.new
		telock.lock_date= params[:lock_date]
		telock.locked_by =User.current.id
		errorMsg =nil
		if !telock.save()
			errorMsg = telock.errors.full_messages.join('\n')
		end
		if errorMsg.nil?
			redirect_to :controller => 'wktime',:action => 'index'
			flash[:notice] = l(:notice_successful_update)
		else
			flash[:error] = errorMsg
			redirect_to :action => 'new'
		end
	 end

	def getSheetView
		"W"
	end

	def hideprevTemplate
		false
	end

	def showProjectDD
		true
	end

	def getLblSpentOn
		l(:field_start_date)
	end

	def getDefultProject
		nil #get from settings
	end

	def showActivityDD
		true
	end

	def getDefultActivity
		nil #get from settings
	end

	def hasApprovalSystem
		!Setting.plugin_redmine_wktime['wktime_use_approval_system'].blank? &&
				Setting.plugin_redmine_wktime['wktime_use_approval_system'].to_i == 1
	end

	def getEntityLabel
		l(:label_wktime)
	end

	def getLblIssue
		l(:field_issue)
	end

	def getLblSpentFor
		l(:label_spent_for)
	end

	# ============ supervisor code merge =========

	def get_my_report_users
		userStr =''
		members = Array.new
		if params[:filter_type].to_s == '4'
			members = getDirectReportUsers (User.current.id)
		elsif params[:filter_type].to_s == '5'
			members = getReportUsers(User.current.id)
		end
		members.each do |m|
			userStr << m.id.to_s() + ',' + m.firstname + ' ' + m.lastname + "\n"
		end
		respond_to do |format|
			format.text  { render :plain => userStr }
		end
	end

	# ============ End of supervisor code merge =========

	def get_projects
		set_loggable_projects
		if params[:format].present?
			respond_to do |format|
				format.text {
					projs = ""
					@logtime_projects.map { |proj| projs << proj.id.to_s + '|' + proj.name + "\n" }
					render plain: projs
				}
			end
		else
			projs = @logtime_projects.map { |proj| { value: proj.id, label: proj.name }}
			render json: projs
		end
	end

	def get_api_users
		key = "id"
		case params["type"]
		when "Project"
			params[:project_id] = params[:id]
			key = "user_id"
			users = getProjMembers()
		when "Group"
			params[:group_id] = params[:id]
			users = getGroupUsers()
		else
			users = User.order("#{User.table_name}.firstname ASC,#{User.table_name}.lastname ASC")
		end
		reUsers = []
		(users || []).each{|user| reUsers << { value: user[key], label: user.name }}
		respond_to do |format|
			format.json  { render(json: reUsers) }
		end
	end

  def showAttachments
    true
  end

	def getModelName
		'TimeEntry'
	end

	def saveWKstatuses(entry)
		wkStatuses = WkStatus.new
		wkStatuses.status_for_type = getModelName
		wkStatuses.status_for_id = entry.id
		wkStatuses.status = !params[:wktime_approve].blank? || !params[:wktime_submit].blank? ? 'a' : 'r'
		wkStatuses.status_date = Time.now
		wkStatuses.status_by_id = User.current.id
		wkStatuses.save
	end

	def destroyWKstatuses(status, entries)
		wkStatuses = WkStatus.where(status_for_type: getModelName, status: status)
		wkStatuses = wkStatuses.where(status_for_id: (entries || []).pluck(:id))
		wkStatuses.destroy_all() unless wkStatuses.blank?
	end

	def check_module_permission
		unless showTime
			render_403
			return false
		end
	end

	def get_approved_leaves
		weeklyentries = {}
		(WkLeaveReq.getApprovedLeaves(@user.id, @startday)).each do |leave|
			issue_id = leave.leave_type_id
			(leave.start_date.to_date..leave.end_date.to_date).each do |date|
				key = update_entry_key(issue_id.to_s+"_"+1.to_s, weeklyentries, date-@startday)
				entry = TimeEntry.new(project_id: leave&.leave_type&.project_id, issue_id: issue_id, spent_on: date, hours: getLeaveAccural(issue_id), comments: leave.leave_reasons)
				weeklyentries[key][0][date-@startday] = entry
			end
		end
		weeklyentries.merge(get_holiday)
	end

	def update_entry_key(key, entries, position)
		entries[key] ||= []
		entries[key][0] ||= Array.new(7, nil)
		if entries[key][0][position].present?
			keys = key.split("_")
			key = keys.first+"_"+(keys.last.to_i+1).to_s
			update_entry_key(key, entries, position)
		end
		key
	end

	def get_holiday
		issue_id = Setting.plugin_redmine_wktime['wktime_holiday'].to_i
		issue = Issue.where(id: issue_id).first
		holidayEntries = {}
		if issue_id > 0 && issue.present?
			(WkPublicHoliday.publicHolidayDetails(@startday, @startday+6.days, @user.id)).each do |date_entry|
				date = date_entry.holiday_date
				key = update_entry_key(issue_id.to_s+"_"+1.to_s, holidayEntries, date-@startday)
				entry = TimeEntry.new(project_id: issue&.project_id, issue_id: issue_id, spent_on: date, hours: getLeaveAccural(issue_id), comments: date_entry.description)
				holidayEntries[key][0][date-@startday] = entry
			end
		end
		holidayEntries
	end

private

	def getManager(user, approver)
		hookMgr = call_hook(:controller_get_manager, {:user => user, :approver => approver})
		mngrArr = [] #nil
		if !hookMgr.blank?
			mngrArr = hookMgr[0] if !hookMgr[0].blank?
		else
			#includeAppr = (!Setting.plugin_redmine_wktime['wktime_own_approval'].blank? && Setting.plugin_redmine_wktime['wktime_own_approval'].to_i == 1 )
			apprPerm = "and r.permissions like '%approve_time_entries%'"
			queryStr = "select distinct u.* from projects p" +
					" inner join members m on p.id = m.project_id and p.status = 1 " +
					#" #{!includeAppr ? ('and m.user_id <> ' + user.id.to_s) : ''}" +
					" inner join member_roles mr on m.id = mr.member_id" +
					" inner join roles r on mr.role_id = r.id and (r.permissions like '%edit_time_entries%' " +
					" #{approver ? apprPerm : ''}" + ')' +
					" inner join users u on m.user_id = u.id" +
					" inner join members m1 on p.id = m1.project_id and m1.user_id = #{user.id}"
					queryStr += get_comp_condition('p', 'where') + get_comp_condition('m') + get_comp_condition('mr') + get_comp_condition('r') + get_comp_condition('u')
			mngrs = User.find_by_sql(queryStr)
			mngrs.each do |m|
				mngrArr << m
			end
		end
		mngrArr
	end

	def setUserCFQuery
		userfilters = getUserCFFromSession
		user_custom_fields = CustomField.where(['is_filter = ? AND type = ?', true, "UserCustomField"])
		@query = nil
		unless user_custom_fields.blank?
			@query = WkTimeEntryQuery.build_from_params(params, :project => nil, :name => '_')
			@query.filters = userfilters if !@query.blank?
		end
	end

	def getUserIds
		user_id = getUserIdFromSession
		label_te = getTELabel

		ids = nil
		if user_id.blank?
			ids = User.current.id.to_s
		elsif user_id.to_i == 0
			ids = getUserIdsFromSession
			ids = '0' if ids.nil?
		else
			ids = user_id
		end
		ids
	end

	def check_permission
		ret = false
		setup
		set_user_projects
		status = getTimeEntryStatus(@startday, @user_id)
		approve_projects = @approvable_projects & @logtime_projects
		if (status != 'n' && (!approve_projects.blank? && approve_projects.size > 0))
			#for approver
			ret = true
		else
			if !@manage_projects.blank? && @manage_projects.size > 0 || @manage_others_log.present? && @manage_others_log.size > 0
				#for manager
					manage_log_projects = @manage_projects || @manage_others_log
					ret = (!manage_log_projects.blank? && manage_log_projects.size > 0)
			else
				#for individuals
				ret = (@user.id == User.current.id && (@logtime_projects.size > 0 || @edit_own_logs.size > 0))
			end
		end
		# editPermission = call_hook(:controller_check_permission, {:params => params})
		if	isSupervisorApproval #!editPermission.blank?
			ret = isSupervisorForUser((params[:user_id]).to_i) || (@user.id == User.current.id && @logtime_projects.size > 0) #editPermission[0]
		end
		return (ret || validateERPPermission('A_TE_PRVLG'))
	end

	def getGrpMembers
		userList = []
		if !params[:group_id].blank?
			group_id = params[:group_id]
		else
			group_id = session[controller_name].try(:[], :group_id)
		end
		# grpMember = call_hook(:controller_group_member,{ :group_id => group_id})
		if isSupervisorApproval #!grpMember.blank?
			#userList = grpMember[0].blank? ? userList : grpMember[0]
			userIds = getReportUserIdsStr
			cond = "1=1"
			unless validateERPPermission('A_TE_PRVLG')
				cond =	"#{User.table_name}.id in(#{userIds})"
			end
			unless group_id.blank?
				userList = get_group_membersByCond(group_id,cond) #get_group_membersByCond
			end
		else
			projMembers = []
			groupusers = nil
			groupusers = User.in_group(group_id) if !group_id.nil?
			#groupusers = getUsersbyGroup
			projMembers = Principal.member_of(@manage_view_spenttime_projects)
			userList = (groupusers || []) & projMembers
			userList = userList.sort
		end
		userList
	end

	def getCondition(date_field, user_id, start_date, end_date=nil)
		cond = nil
		if end_date.nil?
			cond = user_id.nil? ? [ date_field + ' = ?', start_date] :
				[ date_field + ' = ? AND user_id = ?', start_date, user_id]
		else
			cond = user_id.nil? ? [ date_field + ' BETWEEN ? AND ?', start_date, end_date] :
			[ date_field + ' BETWEEN ? AND ? AND user_id = ?', start_date, end_date, user_id]
		end
		return cond
	end

	def prevTemplate(user_id)
		prev_entries = nil
		noOfWeek = Setting.plugin_redmine_wktime['wktime_previous_template_week']

		if !noOfWeek.blank?
			entityNames = getEntityNames
			sDay= getDateSqlString('t.spent_on')
			sqlStr = "select t.* from " + entityNames[1] + " t inner join ( "
			if ActiveRecord::Base.connection.adapter_name == 'SQLServer'
				sqlStr += "select TOP " + noOfWeek.to_s + sDay + " as startday" +
					" from  " + entityNames[1] + " t where user_id = " + user_id.to_s + get_comp_condition('t') +
					" group by " + sDay + " order by startday desc ) as v"
			else
				sqlStr += "select " + sDay + " as startday" +
						" from  " + entityNames[1] + " t where user_id = " + user_id.to_s + get_comp_condition('t') +
						" group by startday order by startday desc limit " + noOfWeek.to_s + ") as v"
			end

			sqlStr +=" on " + sDay + " = v.startday where user_id = " + user_id.to_s + get_comp_condition('t') +
					" order by t.project_id, t.issue_id, t.activity_id"

			prev_entries = TimeEntry.find_by_sql(sqlStr)
		end
		prev_entries
	end

	def gatherEntries
 		entryHash = params[:time_entry]
		@entries ||= Array.new
		custom_values = Hash.new
		#setup
		decimal_separator = l(:general_csv_decimal_separator)
		use_detail_popup = !Setting.plugin_redmine_wktime['wktime_use_detail_popup'].blank? &&
			Setting.plugin_redmine_wktime['wktime_use_detail_popup'].to_i == 1
		custom_fields = TimeEntryCustomField.all
		@wkvalidEntry=false
		@teEntrydisabled=false
		unless entryHash.nil?
			entryHash.each_with_index do |entry, i|
				if !entry['project_id'].blank? && params['hours' + (i+1).to_s()].present?
					hours = params['hours' + (i+1).to_s()]
					ids = params['ids' + (i+1).to_s()]
					comments = params['comments' + (i+1).to_s()]
					disabled = params['disabled' + (i+1).to_s()]
					spentForIds = params['spentForId' + (i+1).to_s()]
					@wkvalidEntry=true
					if use_detail_popup
						custom_values.clear
						custom_fields.each do |cf|
							custom_values[cf.id] = params["_custom_field_values_#{cf.id}"+"_"+(i+1).to_s()]
						end
					end

					j = 0
					ids.each_with_index do |id, k|
						if disabled[k] == "false"
							if(!id.blank? || !hours[j].blank?)
								teEntry = nil
								teEntry = getTEEntry(id)
								setSpentForID(entry, spentForIds, k)
								entry.permit!
								teEntry.attributes = entry
								# since project_id and user_id is protected
								teEntry.project_id = entry['project_id']
								teEntry.issue_id = nil if entry['issue_id'].blank?
								teEntry.user_id = @user.id
								if @renderer.showSpentOnInRow
									teEntry.spent_on = showSpentFor ? entry['spent_for_attributes']['spent_on_time'] : entry['spent_on']
								else
									teEntry.spent_on = @startday + k
								end
								setSpentFor(entry, teEntry, spentForIds, k)

								#for one comment, it will be automatically loaded into the object
								# for different comments, load it separately
								unless comments.blank?
									teEntry.comments = comments[k].blank? ? nil : comments[k]
								end
								#timeEntry.hours = hours[j].blank? ? nil : hours[j].to_f
								#to allow for internationalization on decimal separator
								setValueForSpField(teEntry,hours[j],decimal_separator,entry)
								#teEntry.hours = hours[j].blank? ? nil : hours[j]#.to_f

								# Save Attachments
								saveAttachments(teEntry, i+1, k+1)

								unless custom_fields.blank?
									teEntry.custom_field_values.each do |custom_value|
										custom_field = custom_value.custom_field

										#if it is from the row, it should be automatically loaded
										if !((!Setting.plugin_redmine_wktime['wktime_enter_cf_in_row1'].blank? &&
											Setting.plugin_redmine_wktime['wktime_enter_cf_in_row1'].to_i == custom_field.id) ||
											(!Setting.plugin_redmine_wktime['wktime_enter_cf_in_row2'].blank? &&
											Setting.plugin_redmine_wktime['wktime_enter_cf_in_row2'].to_i == custom_field.id))
											if use_detail_popup
												cvs = custom_values[custom_field.id]
												#custom_value.value = cvs[k].blank? ? nil : (custom_field.multiple? ? cvs[k].split(',') : cvs[k])
												teEntry.custom_field_values = {custom_field.id => cvs[k].blank? ? nil : (custom_field.multiple? ? cvs[k].split(',') : cvs[k])}
											end
										end
									end
								end
								@entries << teEntry
							end
							j += 1
						else
							@teEntrydisabled=true
						end
					end
				end
			end
		end
  end

	def gatherWkCustomFields(wktime)
		errorMsg = nil
		cvParams = nil
		if api_request?
			teName = getTEName()
			wktimeParams = params[:"wk_#{teName}"][:custom_fields]
			cvParams = getAPIWkCustomFields(wktimeParams)	unless wktimeParams.blank?
		else
			wktimeParams = params[:wktime]
			cvParams = wktimeParams[:custom_field_values] unless wktimeParams.blank?
		end
		#custom_values = Hash.new
		custom_fields = WktimeCustomField.all
		if !custom_fields.blank? && !cvParams.blank?
			wktime.custom_field_values.each do |custom_value|
				custom_field = custom_value.custom_field
				cvs = cvParams["#{custom_field.id}"]
				if cvs.blank? && custom_field.is_required
					errorMsg = "#{custom_field.name} #{l('activerecord.errors.messages.blank')} "
					break
				end
				custom_value.value = cvs.blank? ? nil :
					custom_field.multiple? ? cvs.split(',') : cvs
			end
		end
		return errorMsg
	end

	def getAPIWkCustomFields(wktimeParams)
		wkCustField = wktimeParams
		custFldValues = nil
		if !wkCustField.blank?
			custFldValues = Hash.new
			wkCustField.each do |cf|
				custFldValues["#{cf[:id]}"] = cf[:value]
			end
		end
		custFldValues
	end

	def gatherAPIEntries
		errorMsg = nil
		wkte_entries = Hash.new
		teName = getTEName()
		entityNames = getEntityNames()
		@entries = Array.new
		decimal_separator = l(:general_csv_decimal_separator)
		@total = 0
		spField = getSpecificField()
		createSpentOnHash(@startday)
		@wkvalidEntry = true
		@teEntrydisabled=true
		begin
		wkte_entries = params[:"wk_#{teName}"][:"#{entityNames[1]}"]
		if !wkte_entries.blank?
			wkte_entries.each do |entry|
				if !entry[:project].blank?
					id = entry[:id]
					teEntry = nil
					teEntry = getTEEntry(id)
					teEntry.safe_attributes = entry
					if (!entry[:user].blank? && !entry[:user][:id].blank? && @user.id != entry[:user][:id].to_i)
						raise "#{l(:field_user)} #{l('activerecord.errors.messages.invalid')}"
					else
						teEntry.user_id = @user.id
					end
					if !@hrPerDay.has_key?(entry[:spent_on])
						raise "#{l(:label_date)} #{l('activerecord.errors.messages.invalid')}"
					end
					teEntry.project_id = entry[:project][:id] if !entry[:project].blank?
					if (Setting.plugin_redmine_wktime['wktime_allow_blank_issue'].blank? && (entry[:issue].blank? || entry[:issue][:id].blank?))
						raise "#{l(:field_issue)} #{l('activerecord.errors.messages.blank')} "
					else
						if !entry[:issue].blank? && !entry[:issue][:id].blank?
							teEntry.issue_id = entry[:issue][:id]
						else
							teEntry.issue_id = nil
						end
					end
					teEntry.activity_id = entry[:activity][:id] if !entry[:activity].blank?
					setValueForSpField(teEntry,(entry[:"#{spField}"].to_s),decimal_separator,entry)
					@hrPerDay[entry[:spent_on]] = "#{@hrPerDay[entry[:spent_on]]}".to_f + (entry[:"#{spField}"].to_s).gsub(decimal_separator, '.').to_f
					@total = @total + (entry[:"#{spField}"].to_s).gsub(decimal_separator, '.').to_f
					setSpentFor(entry, teEntry, [entry[:spent_for_id]], 0)
					@entries << teEntry
				end
			end
		end
		rescue Exception => e
			errorMsg = e.message
		end
		errorMsg
	end

	def findWkTE(start_date, end_date=nil)
		setup
		cond = getCondition('begin_date', @user.nil? ? nil : @user.id, start_date, end_date)
		findWkTEByCond(cond)
		@wktime = @wktimes[0] unless @wktimes.blank?
	end

	def findWkTEHash(start_date, end_date)
		@wktimesHash ||= Hash.new
		@wktimesHash.clear
		findWkTE(start_date, end_date)
		@wktimes.each do |wktime|
			@wktimesHash[wktime.user_id.to_s + wktime.begin_date.to_s] = wktime
		end
	end

	def render_edit
		set_user_projects
		render :action => 'edit', :user_id => params[:user_id], :startday => @startday
	end

  def check_perm_and_redirect
    unless check_permission
      render_403
      return false
    end
  end

	def user_allowed_to?(privilege, entity)
		setup
		# hookPerm = call_hook(:controller_check_permission, {:params => params})
		allow = false
		if isSupervisorApproval && (@user != User.current) # !hookPerm.blank?
			allow = isSupervisorForUser((params[:user_id]).to_i) #hookPerm[0]
		else
			allow = User.current.allowed_to?(privilege, entity)
		end
		#return @user.allowed_to?(privilege, entity)
		return allow
	end

  def can_log_time?(project_id)
		ret = false
		set_loggable_projects
		loggable_projects = @logtime_projects
		if !@manage_projects.blank? && @user != User.current
			loggable_projects = @manage_projects & @logtime_projects
		end
		loggable_projects.each do |lp|
			if lp.id == project_id
				ret = true
				break
			end
		end
		return ret
  end

	def check_editperm_redirect
		# hookPerm = call_hook(:controller_edit_timelog_permission, {:params => params})
		if isSupervisorApproval #!hookPerm.blank?
			allow = (canSupervisorEdit && isSupervisorForUser((params[:user_id]).to_i)) || (check_editPermission && @user.id == User.current.id) || validateERPPermission('A_TE_PRVLG')
		else
			allow = check_editPermission
		end
		unless allow
			render_403
			return false
		end
	end

  def check_editPermission
		allowed = true
		hasBilledEntry = false
		if api_request?
			ids = gatherIDs
		else
			ids = params['ids']
		end
		if !ids.blank?
			@entries = findTEEntries(ids)
		else
			setup
			cond = getCondition('spent_on', @user.id, @startday, @startday+6)
			@entries = findEntriesByCond(cond)
		end
		@entries.each do |entry|
			if isBilledTimeEntry(entry)
				hasBilledEntry = true
				allowed = false
				break
			end
			if(!entry.editable_by?(User.current))
				allowed = false
			end
		end
		allowed = true if validateERPPermission('A_TE_PRVLG') && !hasBilledEntry
		return allowed
	end

	def updateEntry(entry)
		errorMsg = nil
		if entry.hours.blank?
			# delete the time_entry
			# if the hours is empty but id is valid
			# entry.destroy() unless ids[i].blank?
			if !entry.id.blank?
				if !entry.destroy()
					errorMsg = entry.errors.full_messages.join('\n')
				end
			end
		else
			#if id is there it should be update otherwise create
			#the UI disables editing of
			if can_log_time?(entry.project_id) || to_boolean(@edittimelogs)
				issueId = entry.issue_id
				if entry.issue_id == -1
					entry.issue_id = ''
				end

				activityId = entry.activity_id
				if entry.activity_id == -1
					entry.activity_id = ''
				end

				if ((Setting.plugin_redmine_wktime['wktime_allow_blank_issue'].blank? ||
						Setting.plugin_redmine_wktime['wktime_allow_blank_issue'].to_i == 0) &&
						entry.issue.blank?)
					errorMsg = "#{l(:field_issue)} #{l('activerecord.errors.messages.blank')} "
				end
				if !entry.save()
					errorMsg = errorMsg.blank? ? entry.errors.full_messages : entry.errors.full_messages.unshift(errorMsg)
					errorMsg = errorMsg.join("<br>")
				end

				if issueId == -1
					entry.issue_id = -1
				end

				if activityId == -1
					entry.activity_id = -1
				end
			else
				errorMsg = "For project: " + (entry.project ? entry.project.name : "") + (entry.issue_id.present? ? " , issue #" + entry.issue_id.to_s + ": " +
				entry.issue.subject : " ")
			end
		end
		return errorMsg
	end

	def updateWktime
		errorMsg = nil
		@wktime.begin_date = @startday
		@wktime.user_id = @user.id
		@wktime.statusupdater_id = User.current.id
		@wktime.statusupdate_on = Date.today
		if !@wktime.save()
			errorMsg = @wktime.errors.full_messages.join('\n')
		end
		return errorMsg
	end

	def saveAttachments(teEntry, row, col)
		attachments = []
		if params["attachments_"+row.to_s+"_"+col.to_s].present?
			params["attachments_"+row.to_s+"_"+col.to_s].each do |atch_param|
				attachment = Attachment.find_by_token(atch_param[1][:token])
				next if attachment.blank?
				attachment.container_type = getModelName
				attachment.filename = attachment.filename
				attachment.description = atch_param[1][:description]
				attach = attachment.as_json
				attach[:id] = nil
				attachments << attach
				attachment.delete
			end
		end
		teEntry.attachments_attributes = attachments
	end

	# update timesheet status
	def updateStatus(status)
		errorMsg = nil
		if @wktimes.blank?
			errorMsg = l(:error_wktime_save_nothing)
		else
			@wktime.statusupdater_id = User.current.id
			@wktime.statusupdate_on = Date.today
			@wktime.status = status
			if !@wktime.save()
				errorMsg = @wktime.errors.full_messages.join('\n')
			end
		end
		return errorMsg
	end

	# delete a timesheet
	def deleteWktime
		errorMsg = nil
		unless @wktime.nil?
			if !@wktime.destroy()
				errorMsg = @wktime.errors.full_messages.join('\n')
			end
		end
		return errorMsg
	end

  # Retrieves the date range based on predefined ranges or specific from/to param dates
  def retrieve_date_range
    @free_period = false
    @from, @to = nil, nil
		if params[:control] =='reportdetail' || params[:control] =='report'
			period_type =  params[:period_type]
			period = params[:period]
			fromdate = todate= nil
		else
			period_type = session[controller_name].try(:[], :period_type)
			period = session[controller_name].try(:[], :period)
			fromdate = session[controller_name].try(:[], :from)
			todate = session[controller_name].try(:[], :to)
		end

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
    	#elsif params[:period_type] == '2' || (params[:period_type].nil? && (!params[:from].nil? || !params[:to].nil?))
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

	# set project/group members
	def setMembers
		@groups = Group.sorted.all
		@members = Array.new
		projMem = nil
		filter_type = session[controller_name].try(:[], :filter_type)
		project_id = session[controller_name].try(:[], :project_id)
		# hookMem = call_hook(:controller_get_member, { :filter_type => filter_type})
		if filter_type == '1' #|| (hookMem.blank? && filter_type !='2')
			# hookProjMem = call_hook(:controller_project_member, {  :project_id => project_id})
			if isSupervisorApproval #!hookProjMem.blank?
				projMem = getSupervisorMembers(project_id) #hookProjMem[0].blank? ? [] : hookProjMem[0]
			else
				projMem = @selected_project.members.order("#{User.table_name}.firstname ASC,#{User.table_name}.lastname ASC") if !@selected_project.blank?
			end
			@members = projMem.collect{|m| [ m.name, m.user_id ] } if !projMem.blank?
		elsif filter_type == '2'
			userList = []
			userList = getGrpMembers
			userList.each do |users|
				@members << [users.name,users.id.to_s()]
			end
		else
			if isSupervisorApproval && isSupervisor
				userList = Array.new
				if filter_type == '4'
					userList = getDirectReportUsers (User.current.id)
				elsif filter_type == '5'
					userList = getReportUsers(User.current.id)
				end
				userList.each do |users|
					@members << [users.name,users.id.to_s()]
				end
				# @members = hookMem[0].blank? ? @members : hookMem[0]
			else
				projMem = @selected_project.members.order("#{User.table_name}.firstname ASC,#{User.table_name}.lastname ASC") if !@selected_project.blank?
				@members = projMem.collect{|m| [ m.name, m.user_id ] } if !projMem.blank?
			end
		end
		@members = @members.uniq
	end

  def setup
		teName = getTEName()
		if api_request? && params[:startday].blank?
			startday = params[:"wk_#{teName}"].try(:[], :startday).to_s.to_date
		else
			startday = params[:startday].to_s.to_date
		end
		if api_request? && params[:user_id].blank?
			user_id = params[:"wk_#{teName}"].try([:user], :id)
		else
			user_id = params[:user_id]
		end
		if api_request? && params[:project_id].blank?
			@projectId = params[:"wk_#{teName}"].try(:[], :project_id)
		else
			@projectId = params[:project_id]
		end
		if api_request? && params[:spent_for_key].blank?
			spentForKey = params[:"wk_#{teName}"].try(:[], :spent_for_key)
		else
			spentForKey = params[:spent_for_key]
		end
		@spentForType = nil
		@spentForId = nil
		unless spentForKey.blank?
			spentFor = getSpentFor(spentForKey)
			if spentFor[1].to_i > 0
				@spentForType = spentFor[0]
				@spentForId = spentFor[1].to_i
			end
		end
		if api_request? && params[:issue_id].blank?
			@issueId = params[:"wk_#{teName}"].try(:[], :issue_id)
		else
			@issueId = params[:issue_id]
		end
		# if user has changed the startday
		startday ||= Date.today
		@selectedDate = startday
		if api_request? && params[:sheet_view].blank?
			@selectedDate = params[:"wk_#{teName}"].try(:[], :selected_date).to_s.to_date
		end
		@startday ||= getStartDay(startday)
		@user ||= user_id.present? ? User.unscoped.find(user_id) : User.unscoped.current
		sheetView = getSheetView()
		@renderer = SheetViewRenderer.getInstance(sheetView)
	end

	def set_user_projects
		set_loggable_projects
		set_managed_projects
		set_approvable_projects
	end

	def set_managed_projects
		# from version 1.7, the project member with 'edit time logs' permission is considered as managers
		@manage_others_log = Project.where(Project.allowed_to_condition(User.current, :log_time))
			.where(Project.allowed_to_condition(User.current, :log_time_for_other_users))
			.order('name')
		if validateERPPermission('A_TE_PRVLG')
			@manage_projects = getAccountUserProjects
		elsif isSupervisorApproval
			@manage_projects = getUsersProjects(User.current.id, true)
		else
			@manage_projects ||= Project.where(Project.allowed_to_condition(User.current, :edit_time_entries)).order('name')
		end
		@manage_projects =	setTEProjects(@manage_projects)

		# @manage_view_spenttime_projects contains project list of current user with edit_time_entries and view_time_entries permission
		# @manage_view_spenttime_projects is used to fill up the dropdown in list page for managers
			if validateERPPermission('A_TE_PRVLG') || isSupervisorApproval
				@manage_view_spenttime_projects = @manage_projects
			else
				@view_spenttime_projects ||= Project.where(Project.allowed_to_condition(User.current, :view_time_entries)).order('name')
				@manage_view_spenttime_projects = @manage_projects & @view_spenttime_projects | @manage_others_log & @view_spenttime_projects
				@manage_view_spenttime_projects = setTEProjects(@manage_view_spenttime_projects)
			end

		# @currentUser_loggable_projects contains project list of current user with log_time permission
		# @currentUser_loggable_projects is used to show/hide new time & expense sheet link
		@currentUser_loggable_projects ||= Project.where(Project.allowed_to_condition(User.current, :log_time), Project.allowed_to_condition(User.current, :log_time_for_other_users)).order('name')
		@currentUser_loggable_projects = setTEProjects(@currentUser_loggable_projects)
	end

	def set_loggable_projects
		if api_request? && params[:user_id].blank?
			teName = getTEName()
			u_id = params[:"wk_#{teName}"][:user][:id]
		else
			u_id = params[:user_id]
		end
		if !u_id.blank?	&& u_id.to_i != 0
			@user ||= User.find(u_id)
			if User.current == @user
				@logtime_projects ||= Project.where(Project.allowed_to_condition(User.current, :log_time)).order('name')
				@edit_own_logs = Project.where(Project.allowed_to_condition(User.current, :edit_own_time_entries)).order('name')
			else
				hookProjs = call_hook(:controller_get_permissible_projs, {:user => User.current})
				if !hookProjs.blank?
					@logtime_projects = hookProjs[0].blank? ? [] : hookProjs[0]
				else
					@logtime_projects = Project.where(Project.allowed_to_condition(User.current, :log_time))
					.where(Project.allowed_to_condition(User.current, :log_time_for_other_users) +
						' OR ' + Project.allowed_to_condition(User.current, :edit_time_entries))
					.where(Project.allowed_to_condition(@user, :log_time))
					.order('name')
				end
			end
			@logtime_projects = setTEProjects(@logtime_projects)
		end
	end

	def set_project_issues(entries)
		@projectIssues ||= Hash.new
		@projActivities ||= Hash.new
		@projClients ||= Hash.new
		@projectIssues.clear
		@projActivities.clear
		@projClients.clear
		entries.each do |entry|
			set_visible_issues(entry)
		end
		#load the first project in the list also
		set_visible_issues(nil)
	end

	def set_visible_issues(entry)
		holidayProj = getProjByIssue(Setting.plugin_redmine_wktime['wktime_holiday']) if Setting.plugin_redmine_wktime['wktime_holiday'].to_i > 0 && @holidayEntries.present? && getTELabel == 'Timesheet'
		hProj = Project.where(:id => holidayProj.to_i)
		project = entry.nil? ? (holidayProj.present? ? hProj[0] : @logtime_projects.present? ? @logtime_projects[0] : nil) : entry.project
		project_id = project.nil? ? 0 : project.id
		issueAssignToUsrCond = getIssueAssignToUsrCond
		if @projectIssues[project_id].blank?
			allIssues = Array.new
			trackerids=nil
			if(!params[:tracker_ids].blank? && params[:tracker_ids] != "0")
				trackerids = " AND #{Issue.table_name}.tracker_id in(#{params[:tracker_ids]})"
			end
			if Setting.plugin_redmine_wktime['wktime_closed_issue_ind'].to_i == 1
				if !Setting.plugin_redmine_wktime[getTFSettingName()].blank? &&  Setting.plugin_redmine_wktime[getTFSettingName()] != ["0"] && params[:tracker_ids].blank?
					cond=["(#{Issue.table_name}.tracker_id in ( ?) #{issueAssignToUsrCond} ) and #{Issue.table_name}.project_id in ( #{project_id} )",Setting.plugin_redmine_wktime[getTFSettingName()]]
          #allIssues = Issue.find_all_by_project_id(project_id , :conditions =>  ["#{Issue.table_name}.tracker_id in ( ?) ",Setting.plugin_redmine_wktime[getTFSettingName()]])
					allIssues = Issue.where(cond)
        else
					if (!Setting.plugin_redmine_wktime['wktime_allow_filter_issue'].blank? && Setting.plugin_redmine_wktime['wktime_allow_filter_issue'].to_i == 1)
						#allIssues = Issue.find_all_by_project_id(project_id,:conditions =>["(#{Issue.table_name}.assigned_to_id= ? OR #{Issue.table_name}.author_id= ?) #{trackerids}", params[:user_id],params[:user_id]])
						user_id = params[:user_id] || User.current.id
						groupIDs = Wktime.getUserGrp(user_id).join(',')
						assignedCnd = groupIDs.present? ? "OR #{Issue.table_name}.assigned_to_id in (#{groupIDs})" : ''
						allIssues = Issue.where(["((#{Issue.table_name}.assigned_to_id= ? #{assignedCnd} OR #{Issue.table_name}.author_id= ?) #{trackerids}) and #{Issue.table_name}.project_id in ( #{project_id})", params[:user_id],params[:user_id]])
					else
						#allIssues = Issue.find_all_by_project_id(project_id)
						allIssues = Issue.where(:project_id => project_id)
					end
        end
			else
				if !Setting.plugin_redmine_wktime[getTFSettingName()].blank? &&  Setting.plugin_redmine_wktime[getTFSettingName()] != ["0"] && params[:tracker_ids].blank?
							cond = ["((#{IssueStatus.table_name}.is_closed = ? OR #{Issue.table_name}.closed_on >= ?) AND  #{Issue.table_name}.tracker_id in ( ?) #{issueAssignToUsrCond}) and #{Issue.table_name}.project_id in ( #{project_id} )",false, @startday,Setting.plugin_redmine_wktime[getTFSettingName()]]
				else
						cond =["((#{IssueStatus.table_name}.is_closed = ? OR #{Issue.table_name}.closed_on >= ?) #{issueAssignToUsrCond} #{trackerids}) and #{Issue.table_name}.project_id in ( #{project_id})",false, @startday]
				end
				#allIssues = Issue.find_all_by_project_id(project_id, :conditions => cond, :include => :status)
				allIssues = Issue.includes(:status).references(:status).where(cond)
			end
			if (!Setting.plugin_redmine_wktime['wktime_allow_filter_issue'].blank? && Setting.plugin_redmine_wktime['wktime_allow_filter_issue'].to_i == 1)
				# adding additional assignee
				userIssues = getGrpUserIssues(params)
				issues = userIssues.present? ? (allIssues + userIssues).uniq : allIssues
			end
      # find the issues which are visible to the user
			@projectIssues[project_id] = allIssues.select {|i| i.visible?(@user) }
    end

		if @projActivities[project_id].blank?
			@projActivities[project_id] = project.activities unless project.nil?
		end
		if @projClients[project_id].blank?
      @projClients[project_id] = project.account_projects.includes(:parent) unless project.nil?
    end
  end

	def getSpecificField
		"hours"
	end

	def getEntityNames
		["#{Wktime.table_name}", "#{TimeEntry.table_name}"]
	end

	def getTEQuery(from, to, ids)
		spField = getSpecificField()
		entityNames = getEntityNames()
		teSelectStr = "select v1.id, v1.user_id, v1.startday as spent_on, v1." + spField
		wkSelectStr = teSelectStr + ", case when w.status is null then 'n' else w.status end as status "
		sqlStr = " from "
		sDay = getDateSqlString('t.spent_on')
		#Martin Dube contribution: 'start of the week' configuration
		if ActiveRecord::Base.connection.adapter_name == 'SQLServer'
			wkSelectStr = wkSelectStr +", un.firstname + ' ' + un.lastname as status_updater "
			sqlStr += "(select " + sDay + " as startday, "
			sqlStr += " t.user_id, sum(t." + spField + ") as " + spField + " ,max(t.id) as id" + " from " + entityNames[1] + " t, users u" +
				" where u.id = t.user_id and u.id in (#{ids})"
			sqlStr += " and t.spent_on between '#{from}' and '#{to}'" unless from.blank? && to.blank?
			sqlStr += " group by " + sDay + ", user_id ) as v1"
		else
			if ActiveRecord::Base.connection.adapter_name == 'SQLite'
				wkSelectStr = wkSelectStr +", un.firstname || ' ' || un.lastname as status_updater "
			else
				wkSelectStr = wkSelectStr +", concat(un.firstname,' ' ,un.lastname) as status_updater "
			end
			sqlStr += "(select " + sDay + " as startday, "
			sqlStr += " t.user_id, sum(t." + spField + ") as " + spField + " ,max(t.id) as id" + " from " + entityNames[1] + " t, users u" +
				" where u.id = t.user_id and u.id in (#{ids})" + get_comp_condition('t') + get_comp_condition('u')
			sqlStr += " and t.spent_on between '#{from}' and '#{to}'" unless from.blank? && to.blank?
			sqlStr += " group by startday, user_id order by startday desc, user_id ) as v1"
		end

		wkSqlStr = " left outer join " + entityNames[0] + " w on v1.startday = w.begin_date and v1.user_id = w.user_id " +  get_comp_condition('w') +
					"left outer join users un on un.id = w.statusupdater_id " +  get_comp_condition('un')

		query = formQuery(wkSelectStr, sqlStr, wkSqlStr)
	end

	def getQuery(teQuery, ids, from, to, status)
		spField = getSpecificField()
		dtRangeForUsrSqlStr =  "(" + getAllWeekSql(from, to) + ") tmp1"
		teSqlStr = "(" + teQuery + ") tmp2"

		selectStr = "select tmp3.id, tmp3.user_id as user_id , tmp3.spent_on as spent_on, tmp3.#{spField} as #{spField}, tmp3.status as status, tmp3.status_updater as status_updater, tmp3.created_on as created_on"
		query = " from (select tmp2.id, tmp1.id as user_id, tmp1.created_on, tmp1.selected_date as spent_on, " +
				"case when tmp2.#{spField} is null then 0 else tmp2.#{spField} end as #{spField}, " +
				"case when tmp2.status is null then 'e' else tmp2.status end as status, tmp2.status_updater from " + dtRangeForUsrSqlStr +
				" left join " + teSqlStr
		query = query + " on tmp1.id = tmp2.user_id and tmp1.selected_date = tmp2.spent_on where tmp1.id in (#{ids})) tmp3 "
		query = query + " left outer join (select min( #{getDateSqlString('t.spent_on')} ) as min_spent_on, t.user_id as usrid from time_entries t, users u "
		query = query + " where u.id = t.user_id and u.id in (#{ids}) " + get_comp_condition('t') + get_comp_condition('u') + " group by t.user_id ) vw on vw.usrid = tmp3.user_id "
		query = query + " left join users AS un on un.id = tmp3.user_id " + get_comp_condition('un')
		query = query + getWhereCond(status)
		return [selectStr, query]
	end

	def findBySql(selectStr, query, orderStr)
		spField = getSpecificField()
		@entry_count = findCountBySql(query, TimeEntry)
    setLimitAndOffset()
		rangeStr = formPaginationCondition()
		get_TE_entries(selectStr + query + orderStr + rangeStr)
		@unit = nil
		@total_hours = findSumBySql(query, spField, TimeEntry)
	end

	def getWhereCond(status)
		current_date = getEndDay(Date.today)
		dateStr = getConvertDateStr('tmp3.created_on')
		query = "WHERE ((tmp3.spent_on between "
		query = query + "case when vw.min_spent_on is null then #{getDateSqlString(dateStr)} else vw.min_spent_on end "
		query = query + "and '#{current_date}') OR "
		query = query + "((tmp3.spent_on < case when vw.min_spent_on is null then #{getDateSqlString(dateStr)} else vw.min_spent_on end "
		query = query + "and tmp3.status <> 'e') "
		query = query + "OR (tmp3.spent_on > '#{current_date}' and tmp3.status <> 'e'))) "
		if !status.blank?
			query += " and tmp3.status in ('#{status.join("','")}') "
		end
		query
	end

	def getAllWeekSql(from, to)
		entityNames = getEntityNames()
		user_cf_sql = @query.user_cf_statement('u') if !@query.blank?

		noOfDays = 't4.i*7*10000 + t3.i*7*1000 + t2.i*7*100 + t1.i*7*10 + t0.i*7'
		sqlStr = "select u.id, u.created_on, v.selected_date from " +
		"(select " + getAddDateStr(from, noOfDays) + " selected_date from " +
		"(select 0 i union select 1 union select 2 union select 3 union select 4 union select 5 union select 6 union select 7 union select 8 union select 9) t0, " +
		"(select 0 i union select 1 union select 2 union select 3 union select 4 union select 5 union select 6 union select 7 union select 8 union select 9) t1, " +
		"(select 0 i union select 1 union select 2 union select 3 union select 4 union select 5 union select 6 union select 7 union select 8 union select 9) t2, " +
		"(select 0 i union select 1 union select 2 union select 3 union select 4 union select 5 union select 6 union select 7 union select 8 union select 9) t3, " +
		"(select 0 i union select 1 union select 2 union select 3 union select 4 union select 5 union select 6 union select 7 union select 8 union select 9) t4) v, " +
		"(select u.id, u.created_on from users u) u "
		sqlStr += " #{user_cf_sql} " if !user_cf_sql.blank?
		sqlStr += (!user_cf_sql.blank? ? " AND " : " WHERE ") + " v.selected_date between '#{from}' and '#{to}' "
	end

	def findWkTEByCond(cond)
		#@wktimes = Wktime.find(:all, :conditions => cond)
		@wktimes = Wktime.where(cond)
	end

	def findEntriesByCond(cond)
		#TimeEntry.joins(:project).joins(:activity).joins("LEFT OUTER JOIN issues ON issues.id = time_entries.issue_id").where(cond).order('projects.name, issues.subject, enumerations.name, time_entries.spent_on')
		@renderer.getSheetEntries(cond, TimeEntry, getFiletrParams)
	end

	def getFiletrParams
		#issueUsersCFId = getSettingCfId('wktime_additional_assignee') #22 # :issue_cf_id => issueUsersCFId,
		givenValues = {:user_id => @user.id, :project_id => @projectId, :selected_date => @selectedDate, :spent_for_type => @spentForType, :spent_for_id => @spentForId, :issue_id => @issueId }
	end

	def setValueForSpField(teEntry,spValue,decimal_separator,entry)
		teEntry.hours = spValue.blank? ? nil : spValue.to_hours
		#if (!spValue.blank? && is_number(spValue.gsub(decimal_separator, '.')))
		#	teEntry.hours = spValue.gsub(decimal_separator, '.').to_f
		#else
		#	teEntry.hours = nil
		#end
	end

	def sendRejectionEmail
		raise_delivery_errors_old = ActionMailer::Base.raise_delivery_errors
		ActionMailer::Base.raise_delivery_errors = true
		begin
		unitLabel = getUnitLabel
		unit = params[:unit].to_s
		WkUserNotification.userNotification(@user.id, @wktime, 'timeRejected')
		 @test = WkMailer.sendRejectionEmail(User.current,@user,@wktime,unitLabel,unit).deliver if WkNotification.first.email
		rescue Exception => e
		 # flash[:error] = l(:notice_email_error, e.message)
		end
		ActionMailer::Base.raise_delivery_errors = raise_delivery_errors_old

	end

	def getWkEntity
		Wktime.new
	end

	def getTEEntry(id)
		id.blank? ? TimeEntry.new : TimeEntry.find(id)
	end

	def deleteWkEntity(cond)
	   Wktime.where(cond).delete_all
	end

	def delete(ids)
		TimeEntry.delete(ids)
	end

	def findTEEntries(ids)
		TimeEntry.find(ids)
	end

	def setTotal(wkEntity,total)
		wkEntity.hours = total
	end

	def setEntityLabel
		l(:label_wktime)
	end

	def setTEProjects(projects)
		projects
	end

	def createSpentOnHash(stDate)
		@hrPerDay = Hash.new
		for i in 0..6
			key = (stDate+i)
			@hrPerDay["#{key}"] = 0
		end
	end

	def validateMinMaxHr(stDate)
		errorMsg = nil
		minHr = minHour().to_i
		maxHr = maxHour().to_i
		if minHr > 0 || maxHr > 0
			nwdays = Setting.non_working_week_days
			phdays = getWdayForPublicHday(stDate)
			holidays = nwdays.concat(phdays)
			for i in 0..6
				key = (stDate+i)
				if (!holidays.include?((key.cwday).to_s) || @hrPerDay["#{key}"] > 0)
					if minHr > 0 && !params[:wktime_submit].blank?
						if @hrPerDay["#{key}"] < minHr
							errorMsg = l(:text_wk_warning_min_hour, :value => "#{minHr}")
							break
						end
					end
					if  maxHr > 0
						if @hrPerDay["#{key}"] > maxHr
							errorMsg = l(:text_wk_warning_max_hour, :value => "#{maxHr}")
							break
						end
					end
				end
			end
		end
		errorMsg
	end

	def set_approvable_projects
		#@approvable_projects ||= Project.find(:all, :order => 'name', :conditions => Project.allowed_to_condition(User.current, :approve_time_entries))
		@approvable_projects ||= Project.where(Project.allowed_to_condition(User.current, :approve_time_entries)).order('name')
	end

	def getTEName
		"time"
	end

	def getSelectedProject(projList, setFirstProj)
		if !params[:tab].blank? && params[:tab] =='wkexpense'
			selected_proj_id = session[controller_name].try(:[], :project_id).blank? ? params[:project_id] : session[controller_name].try(:[], :project_id)
		elsif !session[controller_name].blank?
			selected_proj_id = session[controller_name].try(:[], :project_id)
		end
		if !selected_proj_id.blank? && !setFirstProj #( !isAccountUser || !projList.blank? )
			sel_project = projList.select{ |proj| proj.id == selected_proj_id.to_i } if !projList.blank?
			selected_project ||= sel_project[0] if !sel_project.blank?
		else
			selected_project ||= projList[0] if !projList.blank?
		end
	end

	def check_view_redirect
		# the user with view_time_entries permission will only be allowed to view list page
		unless checkViewPermission
			render_403
			return false
		end
	end

	def check_log_time_redirect
		set_user_projects
		# the user with log_time(for member) or edit time log(for manager) permission will be allowed to enter new time/expense sheet
		if !@currentUser_loggable_projects.blank? || !@manage_projects.blank?
			return true
		else
			render_403
			return false
		end
	end

	def formPaginationCondition
		rangeStr = ""
		if ActiveRecord::Base.connection.adapter_name == 'SQLServer'
			rangeStr = " OFFSET " + @offset.to_s + " ROWS FETCH NEXT " + @limit.to_s + " ROWS ONLY "
		else
			rangeStr = " LIMIT " + @limit.to_s +	" OFFSET " + @offset.to_s
		end
		rangeStr
	end

	def set_edit_time_logs
		# editPermission = call_hook(:controller_edit_timelog_permission, {:params => params})
		# @edittimelogs  = editPermission.blank? ? '' : editPermission[0].to_s
		@edittimelogs  = isSupervisorApproval ? (canSupervisorEdit && isSupervisorForUser((params[:user_id]).to_i)).to_s : ''
	end

	def is_member_of_any_project
		cond =	"user_id = " + User.current.id.to_s
		projMember = Member.where(cond)
		ret = projMember.size > 0
	end

	def get_trackerbyIssue(issue_id)
		result = Issue.where(['id = ?',issue_id]) if !issue_id.blank?
		tracker = !result.blank? ? (result[0].blank? ? '0' : result[0].tracker_id if !result.blank?) : '0'
		tracker
	end

	def set_filter_session
		session[controller_name] = {:filters => @query.blank? ? nil : @query.filters} if session[controller_name].nil? || params[:clear]
		if params[:searchlist] == controller_name || api_request?
			session[controller_name][:filters] = @query.blank? ? nil : @query.filters
			filters = [:period_type, :period, :from, :to, :project_id, :filter_type, :user_id, :status, :group_id]
			filters.each do |param|
				if params[param].blank? && session[controller_name].try(:[], param).present?
					session[controller_name].delete(param)
				elsif params[param].present?
					session[controller_name][param] = params[param]
				end
			end
		end
	end

	def findTEEntryBySql(query)
		TimeEntry.find_by_sql(query)
	end

	def formQuery(wkSelectStr, sqlStr, wkSqlStr)
		query = wkSelectStr + sqlStr + wkSqlStr
	end

	def getUserCFFromSession
		session[controller_name].try(:[], :filters)
	end

	def getUserIdFromSession
		#return user_id from session
		session[controller_name].try(:[], :user_id)
	end

	def get_statusFromSession
		session[controller_name].try(:[], :status)
	end

	def setUserIdsInSession(ids)
		session[controller_name][:all_user_ids] = ids
	end

	def getUserIdsFromSession
		session[controller_name].try(:[], :all_user_ids)
	end

	def setSpentForID(entry, spentForIds, k)
		entry[:spent_for_attributes] = {} if entry[:spent_for_attributes].blank?
		entry[:spent_for_attributes][:id] = spentForIds.present? && spentForIds[k].present? ? spentForIds[k] : nil
	end

	def setSpentFor(entry, teEntry, spentForIds, k)
		spent_for = {}
		spent_for[:id] = spentForIds.present? && spentForIds[k].present? ? spentForIds[k] : nil

		unless entry['spent_for_attributes'].blank?
			unless entry['spent_for_attributes']['spent_for_key'].blank?
				spentFor = getSpentFor(entry['spent_for_attributes']['spent_for_key'])
				if spentFor[1].to_i > 0
					spent_for['spent_for_type'] = spentFor[0]
					spent_for['spent_for_id'] = spentFor[1].to_i
				end
			end
			spent_for['spent_on_time'] = getDateTime(teEntry.spent_on, entry['spent_for_attributes']['spent_date_hr'], entry['spent_for_attributes']['spent_date_min'], 0)
		end
		spent_for['spent_on_time'] = getDateTime(teEntry.spent_on, 0, 0, 0) if entry['spent_for_attributes'].blank?
		# save GeoLocation
    saveGeoLocation(spent_for, params[:latitude], params[:longitude])

		teEntry.spent_for_attributes = spent_for
	end

	def getPDFHeaders()
		headers = [
			[ l(:label_week), 40 ],
			[ l(:field_start_date), 40 ],
			[ l(:field_user), 60 ],
			[ l(:field_status), 40 ],
			[ getLabelforSpField, 40 ]
		]
	end

	def getPDFcells(entry)
		list = [
			[ entry.spent_on&.cweek.to_s, 40 ],
			[ entry.spent_on.to_s, 40 ],
			[ entry.user.name.to_s, 60 ],
			[ statusString(entry.status), 40 ]
		]
		list = getLastPDFCell(list, entry)
	end

	def getPDFFooter(pdf, row_Height)
		pdf.RDMCell( 180, row_Height, l(:label_total), 1, 0, 'R', 1)
		pdf.RDMCell( 40, row_Height, (@total_hours || 0).to_s, 1, 0, '', 1)
	end

	def getLastPDFCell(list, entry)
		list << [ entry.hours.to_s , 40 ]
		list
	end

	def get_TE_entries(query)
		@entries = TimeEntry.find_by_sql(query)
	end

	def issueLogValidation
		errorMsg = ''
		issueLogs = get_issue_loggers(true)
		errorMsg = l(:warn_issuelog_exist) if issueLogs.length > 0
		errorMsg
	end

	def getGrpUserIssues(params)
		user_id = params[:user_id] || User.current.id
		groupIDs = Wktime.getUserGrp(user_id).join(',')
		userIssues = Wktime.getAssignedIssues(user_id, groupIDs, params[:project_id]) if groupIDs.present?
		userIssues ||= []
	end
end