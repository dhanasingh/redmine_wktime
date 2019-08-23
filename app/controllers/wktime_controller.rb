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

class WktimeController < WkbaseController
unloadable

include WktimeHelper
include WkcrmHelper

before_action :require_login
before_action :check_perm_and_redirect, :only => [:edit, :update, :destroy] # user without edit permission can't destroy
before_action :check_editperm_redirect, :only => [:destroy]
before_action :check_view_redirect, :only => [:index]
before_action :check_log_time_redirect, :only => [:new]

accept_api_auth :index, :edit, :update, :destroy, :deleteEntries

helper :custom_fields
helper :queries
include QueriesHelper
 
  def index
	sort_init 'id', 'asc'
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
	query = getQuery(teQuery, ids, @from, @to, status)
	query = query + " ORDER BY " + (sort_clause.present? ? sort_clause.first + ", spent_on DESC " : "tmp3.spent_on desc, tmp3.user_id")
	findBySql(query)
    respond_to do |format|
      format.html {        
        render :layout => !request.xhr?
      }
	  format.api
    end
  end

  def edit
	@prev_template = false
	@new_custom_field_values = getNewCustomField
	setup
	findWkTE(@startday)
	@editable = @wktime.nil? || @wktime.status == 'n' || @wktime.status == 'r'
	# hookPerm = call_hook(:controller_check_editable, {:editable => @editable, :user => @user})
	# @editable = hookPerm.blank? ? @editable : hookPerm[0]
	@editable = canSupervisorEdit if isSupervisorApproval && @editable && isSupervisor
	#below two lines are hook code for lock TE
	# hookPerm = call_hook(:controller_check_locked, {:startdate => @startday})
	# @locked = hookPerm.blank? ? false : hookPerm[0]
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
	if @entries.blank? && !params[:prev_template].blank?
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
						#if !((Setting.plugin_redmine_wktime['wktime_allow_blank_issue'].blank? ||
						#		Setting.plugin_redmine_wktime['wktime_allow_blank_issue'].to_i == 0) && 
						#		entry.issue.blank?)
							if allowSave
								errorMsg = updateEntry(entry) 
							else
								errorMsg = l(:error_not_permitted_save) if !api_request?
							end
							break unless errorMsg.blank?
						#else
						#	errorMsg = "#{l(:field_issue)} #{l('activerecord.errors.messages.blank')} "
						#	break unless errorMsg.blank?
						#end
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

			if errorMsg.blank? && useApprovalSystem
				if !@wktime.nil? && @wktime.status == 's'					
					if !params[:wktime_approve].blank? && allowApprove					 
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
						if email_delivery_enabled? 
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
		if errorMsg.nil?			
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
			if errorMsg.nil?
				flash[:notice] = respMsg
				$tempEntries = nil
				#redirect_back_or_default :action => 'index'
				#redirect_to :action => 'index' , :tab => params[:tab]
                if params[:wktime_save_continue] 
				      redirect_to :action => 'edit' , :startday => !@entries.present? ? @startday  : @startday+ @renderer.getDaysPerSheet, :user_id => @user.id, :project_id => params[:project_id], :sheet_view => @renderer.getSheetType   
				else                                                                                                
				      redirect_to :action => 'index' , :tab => params[:tab]                   
				end 
			else
				flash[:error] = respMsg
				$tempEntries = @entries
				if !params[:enter_issue_id].blank? && params[:enter_issue_id].to_i == 1					
				redirect_to :action => 'edit', :user_id => params[:user_id], :startday => @startday, :isError => true,
				:enter_issue_id => 1	
				else
					redirect_to :action => 'edit', :user_id => params[:user_id], :startday => @startday,:sheet_view => @renderer.getSheetType, :project_id => @projectId, :isError => true
				end
			end
		}
		format.api{
			if errorMsg.blank?
				render :plain => respMsg, :layout => nil
			else			
				@error_messages = respMsg.split('\n')	
				render :template => 'common/error_messages.api', :status => :unprocessable_entity, :layout => nil
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
	def deleteEntries	
		deleterow
	end
	
	def gatherIDs
		ids = Array.new
		entityNames = getEntityNames()
		entries = params[:"#{entityNames[1]}"]
		if !entries.blank?
			entries.each do |entry|		
				ids << entry[:id]
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
	
	def new
		set_user_projects
		@selected_project = getSelectedProject(@manage_projects, true)
		# get the startday for current week
		@startday = getStartDay(Date.today)
		render :action => 'new'
	end
		
	def getIssueAssignToUsrCond
		issueAssignToUsrCond=nil
		if (!params[:issue_assign_user].blank? && params[:issue_assign_user].to_i == 1) 
			issueAssignToUsrCond ="and (#{Issue.table_name}.assigned_to_id=#{params[:user_id]} OR #{Issue.table_name}.author_id=#{params[:user_id]})" 
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
		if  !filterTrackerVisible() && (params[:tracker_id].blank? || !params[:term].blank?)
			params[:tracker_id] = Setting.plugin_redmine_wktime[getTFSettingName()]
			trackerIDCond= "AND #{Issue.table_name}.tracker_id in(#{(Setting.plugin_redmine_wktime[getTFSettingName()]).join(',')})" if !params[:tracker_id].blank? && params[:tracker_id] != ["0"]
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
				if (!params[:issue_assign_user].blank? && params[:issue_assign_user].to_i == 1)
					projIds = "#{(params[:project_id] || (!params[:project_ids].blank? ? params[:project_ids].join(",") : '') || projectids)}"
					projCond = !projIds.blank? ? "AND #{Issue.table_name}.project_id in (#{projIds})" : ""

					issues = Issue.where(["((#{Issue.table_name}.assigned_to_id= ? OR #{Issue.table_name}.author_id= ?) #{trackerIDCond}) #{projCond}", params[:user_id], params[:user_id]]).order('project_id')
				else
					issues = Issue.where(:project_id => params[:project_id] || params[:project_ids]).order('project_id')
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
		issues = issues.select(&:present?)
		user = User.find(params[:user_id])

		if  !params[:format].blank?
			respond_to do |format|
				format.text  { 
					issStr =""
					issues.each do |issue|
					issStr << issue.project_id.to_s() + '|' + issue.id.to_s() + '|' + issue.tracker.to_s() +  '|' + 
							issue.subject  + "\n" if issue.visible?(user)
					end	
				render :plain => issStr 
				}	
			end
		else 
			issStr=[]
			issues.each do |issue|            
				issStr << {:value => issue.id.to_s(), :label => issue.tracker.to_s() +  " #" + issue.id.to_s() + ": " + issue.subject }  if issue.visible?(user)
			end 
			
			render :json => issStr 
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
		actStr =""
		project.activities.each do |a|
			actStr << project_id.to_s() + '|' + a.id.to_s() + '|' + a.is_default.to_s() + '|' + a.name + "\n"
		end
	
		respond_to do |format|
			format.text  { 
			if error.blank?
				render :plain => actStr 
			else
				render_403
			end
			}
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
		clientStr =""
		usrLocationId = teUser.wk_user.blank? ? nil : teUser.wk_user.location_id
		unless project.blank?
			project.account_projects.includes(:parent).order(:parent_type).each do |ap|
				clientStr << project_id.to_s() + '|' + ap.parent_type + '_' + ap.parent_id.to_s() + '|' + "" + (params[:separator].blank? ? '|' : params[:separator] ) + ap.parent.name + "\n" if ap.parent.location_id == usrLocationId
			end
		end
	
		# respond_to do |format|
			# format.text  { 
			# if error.blank?
				# render :plain => clientStr 
			# else
				# render_403
			# end
			# }
		# end
		respond_to do |format|
			format.text  { render :plain => clientStr }
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
		usrLocationId = user.wk_user.blank? ? nil : user.wk_user.location_id
		unless userProjects.blank?
			userProjects.each do |project|
				projectids << project.id
			end
		end
		usrBillableProjects = WkAccountProject.includes(:parent).where(:project_id => projectids)
		locationBillProject = usrBillableProjects.select {|bp| bp.parent.location_id == usrLocationId}
		locationBillProject = locationBillProject.sort_by{|parent_type| parent_type}
		billableClients = locationBillProject.collect {|billProj| [billProj.parent.name, billProj.parent_type.to_s + '_' + billProj.parent_id.to_s]}
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
		userIssues = Issue.includes(:project).joins("INNER JOIN wk_issue_assignees ia on (ia.issue_id = issues.id and ia.user_id = #{userId}) ") 
		assignedIssueUser = Issue.includes(:project).where(:assigned_to_id => userId)
		issueAssignee = userIssues + assignedIssueUser 
		issueAssignee = issueAssignee.uniq
		issueAssignee = issueAssignee.sort_by{|subject| subject}
		assignedIssues = issueAssignee.collect {|issue| [issue.project.name + " #" + issue.id.to_s + ": " + issue.subject, issue.id]}
		assignedIssues.unshift( ["", ""]) if needBlank
		assignedIssues
	end
	
	def getusers
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
			projmembers.each do |m|
				userStr << m.user_id.to_s() + ',' + m.name + "\n"
			end
		end
		respond_to do |format|
			format.text  { render :plain => userStr }
		end
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
	
	def filterTrackerVisible
		!Setting.plugin_redmine_wktime['wktime_allow_user_filter_tracker'].blank?  && Setting.plugin_redmine_wktime['wktime_allow_user_filter_tracker'].to_i == 1
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
		Setting.plugin_redmine_wktime['wktime_restr_max_hour'].to_i == 1 ?  
		(Setting.plugin_redmine_wktime['wktime_max_hour_day'].blank? ? 8 : Setting.plugin_redmine_wktime['wktime_max_hour_day']) : 0
	end
	def minHour
		Setting.plugin_redmine_wktime['wktime_restr_min_hour'].to_i == 1 ?  
		(Setting.plugin_redmine_wktime['wktime_min_hour_day'].blank? ? 0 : Setting.plugin_redmine_wktime['wktime_min_hour_day']) : 0
	end
	
	def total_all(total)
		html_hours(l_hours(total))
	end
	
	 def getStatus
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
	
	def getMembersbyGroup
		group_by_users=""
		userList=[]
		set_managed_projects				
		userList = getGrpMembers
		userList.each do |users|
			group_by_users << users.id.to_s() + ',' + users.name + "\n"
		end
		respond_to do |format|
			format.text  { render :plain => group_by_users }
		end
	end	
	
	def findTEProjects()		
		entityNames = getEntityNames	
		Project.find_by_sql("SELECT DISTINCT p.* FROM projects p INNER JOIN " + entityNames[1] + " t ON p.id=t.project_id  where t.spent_on BETWEEN '" + @startday.to_s +
				"' AND '" +  (@startday+6).to_s + "' AND t.user_id = " + @user.id.to_s)		
	end
	
	def check_approvable_status		
		te_projects=[]
		ret = false
		if !@entries.blank?		
			@te_projects = @entries.collect{|entry| entry.project}.uniq
			te_projects = @approvable_projects & @te_projects if !@te_projects.blank?			
		end
		# hookPerm = call_hook(:controller_check_approvable, {:params => params})		
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
	
	def checkDDWidth
		ret = true
		project_dd_width  = Setting.plugin_redmine_wktime['wktime_project_dd_width'].to_i
		issue_dd_width  = Setting.plugin_redmine_wktime['wktime_issue_dd_width'].to_i
		actv_dd_width  = Setting.plugin_redmine_wktime['wktime_actv_dd_width'].to_i
		ddtotal = project_dd_width  + issue_dd_width  + actv_dd_width 
		if ddtotal > 50
		    ret = false
		end
		ret
	end
	
	def getTracker
		ret = false;
		tracker = getTrackerbyIssue(params[:issue_id])
		settingstracker = Setting.plugin_redmine_wktime[getTFSettingName()]
		allowtracker = Setting.plugin_redmine_wktime['wktime_allow_user_filter_tracker'].to_i
		if settingstracker != ["0"]
			if ((settingstracker.include?("#{tracker}")) || (tracker == '0'))
				ret = true
			end			
		else
			ret = true
		end	
		
		if allowtracker == 1
		ret = true
		end
		
		respond_to do |format|
			format.text  { render :plain => ret }
		end	
	end
	
	def sendSubReminderEmail
		userList = ""
		weekHash = Hash.new
		userHash = Hash.new
		mngrHash = Hash.new
		respMsg = "OK"
		allowedStatus = ['e','r','n'];
		pStatus = getStatusFromSession #params[:status].split(',')
		status = pStatus.blank? ? allowedStatus : (allowedStatus & pStatus)
		wkentries = nil
		if !status.blank?
			ids = getUserIds
			setUserCFQuery
			label_te = getTELabel
			teQuery = getTEQuery(params[:from].to_date, params[:to].to_date, ids)
			query = getQuery(teQuery, ids, params[:from].to_date, params[:to].to_date, status) #['e','r','n']
						
			wkentries = findTEEntryBySql(query)			
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
	
	def sendApprReminderEmail		
		mgrList = ""
		userHash = Hash.new
		mgrHash = Hash.new		
		respMsg = "OK"
		allowedStatus = ['s'];
		pStatus = getStatusFromSession
		status = pStatus.blank? ? allowedStatus : (allowedStatus & pStatus)
		users = nil
		if !status.blank?
			entityNames = getEntityNames
			ids = getUserIds
			setUserCFQuery
			label_te = getTELabel
			user_cf_sql = @query.user_cf_statement('u') if !@query.blank?
			queryStr = "select distinct u.* from users u " +
						"left outer join #{entityNames[0]} w on u.id = w.user_id " +
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
	
	def updateAttendance		
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
				starttime = start_local.change({ hour: entryvalues[1].to_time.strftime("%H"), min: entryvalues[1].to_time.strftime("%M"), sec: entryvalues[1].to_time.strftime("%S") })
				oldendvalue = entryvalues[2]
				if (params[:nightshift] == "true")
					entryvalues[2] = "23:59"
				end
				if !entryvalues[2].blank?
					endtime = start_local.change({ hour: entryvalues[2].to_time.strftime("%H"), min: entryvalues[2].to_time.strftime("%M"), sec: entryvalues[2].to_time.strftime("%S") })
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
	
	############ Moved from private ##############
	
	def showClockInOut
		(!Setting.plugin_redmine_wktime['wktime_enable_clock_in_out'].blank? &&
		Setting.plugin_redmine_wktime['wktime_enable_clock_in_out'].to_i == 1) && (!Setting.plugin_redmine_wktime['wktime_enable_attendance_module'].blank? && Setting.plugin_redmine_wktime['wktime_enable_attendance_module'].to_i == 1 ) && showWorktimeHeader
	end
	
	def maxHourPerWeek
		Setting.plugin_redmine_wktime['wktime_restr_max_hour_week'].to_i == 1 ?  
		(Setting.plugin_redmine_wktime['wktime_max_hour_week'].blank? ? 0 : Setting.plugin_redmine_wktime['wktime_max_hour_week']) : 0
	end
	
	def minHourPerWeek
		Setting.plugin_redmine_wktime['wktime_restr_min_hour_week'].to_i == 1 ?  
		(Setting.plugin_redmine_wktime['wktime_min_hour_week'].blank? ? 0 : Setting.plugin_redmine_wktime['wktime_min_hour_week']) : 0
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
	
	def getMyReportUsers
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
			if !@manage_projects.blank? && @manage_projects.size > 0
				#for manager
				if !@logtime_projects.blank? && @logtime_projects.size > 0
					manage_log_projects = @manage_projects & @logtime_projects
					ret = (!manage_log_projects.blank? && manage_log_projects.size > 0)
				end
			else
				#for individuals
				ret = (@user.id == User.current.id && @logtime_projects.size > 0)
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
				userList = getGroupMembersByCond(group_id,cond) #getGroupMembersByCond
			end	
		else
			projMembers = []			
			groupusers = nil
			
			scope=User.in_group(group_id)  if !group_id.nil?
		
			groupusers = scope.all
			#groupusers = getUsersbyGroup
			projMembers = Principal.member_of(@manage_view_spenttime_projects)
			userList = groupusers & projMembers
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
					" from  " + entityNames[1] + " t where user_id = " + user_id.to_s +
					" group by " + sDay + " order by startday desc ) as v" 
			else
				sqlStr += "select " + sDay + " as startday" +
						" from  " + entityNames[1] + " t where user_id = " + user_id.to_s +
						" group by startday order by startday desc limit " + noOfWeek.to_s + ") as v" 
			end
					
			sqlStr +=" on " + sDay + " = v.startday where user_id = " + user_id.to_s +
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
				if !entry['project_id'].blank?
					hours = params['hours' + (i+1).to_s()]					
					ids = params['ids' + (i+1).to_s()]
					comments = params['comments' + (i+1).to_s()]
					disabled = params['disabled' + (i+1).to_s()]
					@wkvalidEntry=true	
					if use_detail_popup
						custom_values.clear
						custom_fields.each do |cf|
							custom_values[cf.id] = params["_custom_field_values_#{cf.id}" + (i+1).to_s()]
						end
					end
					
					j = 0
					ids.each_with_index do |id, k|
						if disabled[k] == "false"
							if(!id.blank? || !hours[j].blank?)
								teEntry = nil
								teEntry = getTEEntry(id)
								
								entry.permit! #(spent_for: [ :spent_for_type, :spent_on_time ])
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
								
								unless entry['spent_for_attributes'].blank? 
									unless entry['spent_for_attributes']['spent_for_key'].blank?
										spentFor = getSpentFor(entry['spent_for_attributes']['spent_for_key'])
										if spentFor[1].to_i > 0
											teEntry.spent_for.spent_for_type = spentFor[0]
											teEntry.spent_for.spent_for_id = spentFor[1].to_i
										end
									end
									teEntry.spent_for.spent_on_time = getDateTime(teEntry.spent_on, entry['spent_for_attributes']['spent_date_hr'], entry['spent_for_attributes']['spent_date_min'], 0)
								end
								#for one comment, it will be automatically loaded into the object
								# for different comments, load it separately
								unless comments.blank?
									teEntry.comments = comments[k].blank? ? nil : comments[k]	
								end
								#timeEntry.hours = hours[j].blank? ? nil : hours[j].to_f
								#to allow for internationalization on decimal separator
								setValueForSpField(teEntry,hours[j],decimal_separator,entry)
								#teEntry.hours = hours[j].blank? ? nil : hours[j]#.to_f
								
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
				errorMsg = l(:error_not_permitted_save)
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
			if isSupervisorApproval # !hookMem.blank?
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
			startday = params[:"wk_#{teName}"][:startday].to_s.to_date
		else
			startday = params[:startday].to_s.to_date				
		end
		if api_request? && params[:user_id].blank?
			user_id = params[:"wk_#{teName}"][:user][:id]		
		else
			user_id = params[:user_id]			
		end
		if api_request? && params[:project_id].blank?
			@projectId = params[:"wk_#{teName}"][:project_id]	
		else
			@projectId = params[:project_id]			
		end
		if api_request? && params[:spent_for_key].blank?
			spentForKey = params[:"wk_#{teName}"][:spent_for_key]	
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
			@issueId = params[:"wk_#{teName}"][:issue_id]	
		else
			@issueId = params[:issue_id]			
		end
		# if user has changed the startday
		@selectedDate = startday
		if api_request? && params[:sheet_view].blank?
			@selectedDate = params[:"wk_#{teName}"][:selected_date].to_s.to_date
		end
		@startday ||= getStartDay(startday)
		@user ||= User.find(user_id)
		sheetView = params[:sheet_view].blank? ? 'W' : params[:sheet_view]
		@renderer = SheetViewRenderer.getInstance(sheetView)
	end
  
	def set_user_projects
		set_loggable_projects
		set_managed_projects				
		set_approvable_projects
	end
	
	def set_managed_projects
		# from version 1.7, the project member with 'edit time logs' permission is considered as managers
		# mng_projects = call_hook(:controller_set_manage_projects)
		# if !mng_projects.blank?
			# @manage_projects = mng_projects[0].blank? ? nil : mng_projects[0]
		# else
			if validateERPPermission('A_TE_PRVLG')
				@manage_projects = getAccountUserProjects
			elsif isSupervisorApproval
				@manage_projects = getUsersProjects(User.current.id, true)
			else
				@manage_projects ||= Project.where(Project.allowed_to_condition(User.current, :edit_time_entries)).order('name')
			end
		# end		
		@manage_projects =	setTEProjects(@manage_projects)	
		
		# @manage_view_spenttime_projects contains project list of current user with edit_time_entries and view_time_entries permission
		# @manage_view_spenttime_projects is used to fill up the dropdown in list page for managers
		# view_projects = call_hook(:controller_set_view_projects)
		# if !view_projects.blank?
			# @manage_view_spenttime_projects = view_projects[0].blank? ? nil : view_projects[0]
		# else
			if validateERPPermission('A_TE_PRVLG') || isSupervisorApproval
				@manage_view_spenttime_projects = @manage_projects #getAccountUserProjects
			# elsif isSupervisorApproval
				# @manage_view_spenttime_projects = getUsersProjects(User.current.id, true)
			else
				@view_spenttime_projects ||= Project.where(Project.allowed_to_condition(User.current, :view_time_entries)).order('name')
				@manage_view_spenttime_projects = @manage_projects & @view_spenttime_projects
				@manage_view_spenttime_projects = setTEProjects(@manage_view_spenttime_projects)
			end
		# end

		# @currentUser_loggable_projects contains project list of current user with log_time permission
		# @currentUser_loggable_projects is used to show/hide new time & expense sheet link	
		@currentUser_loggable_projects ||= Project.where(Project.allowed_to_condition(User.current, :log_time)).order('name')
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
				@logtime_projects ||= Project.where(Project.allowed_to_condition(@user, :log_time)).order('name')
			else
				hookProjs = call_hook(:controller_get_permissible_projs, {:user => @user})
				if !hookProjs.blank?	
					@logtime_projects = hookProjs[0].blank? ? [] : hookProjs[0]
				else
					user_projects ||= Project
					.joins("INNER JOIN #{EnabledModule.table_name} ON projects.id = enabled_modules.project_id and enabled_modules.name='time_tracking'")
					.joins("INNER JOIN #{Member.table_name} ON projects.id = members.project_id")				
					.where("#{Member.table_name}.user_id = #{@user.id} AND #{Project.table_name}.status = #{Project::STATUS_ACTIVE}")
					logtime_projects ||= Project.where(Project.allowed_to_condition(@user, :log_time)).order('name')
					@logtime_projects = logtime_projects | user_projects
				end
			end
			#@logtime_projects = @logtime_projects & @manage_projects if !@manage_projects.blank?
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
        project = entry.nil? ? (@logtime_projects.blank? ? nil : @logtime_projects[0]) : entry.project
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
					if (!params[:issue_assign_user].blank? && params[:issue_assign_user].to_i == 1) 						
						#allIssues = Issue.find_all_by_project_id(project_id,:conditions =>["(#{Issue.table_name}.assigned_to_id= ? OR #{Issue.table_name}.author_id= ?) #{trackerids}", params[:user_id],params[:user_id]]) 
						allIssues = Issue.where(["((#{Issue.table_name}.assigned_to_id= ? OR #{Issue.table_name}.author_id= ?) #{trackerids}) and #{Issue.table_name}.project_id in ( #{project_id})", params[:user_id],params[:user_id]])
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
		teSelectStr = "select v1.user_id, v1.startday as spent_on, v1." + spField
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
				" where u.id = t.user_id and u.id in (#{ids})"
			sqlStr += " and t.spent_on between '#{from}' and '#{to}'" unless from.blank? && to.blank?	
			sqlStr += " group by startday, user_id order by startday desc, user_id ) as v1"		
		end		

		wkSqlStr = " left outer join " + entityNames[0] + " w on v1.startday = w.begin_date and v1.user_id = w.user_id " +
					"left outer join users un on un.id = w.statusupdater_id "
		
		query = formQuery(wkSelectStr, sqlStr, wkSqlStr)
	end
	
	def getQuery(teQuery, ids, from, to, status)
		spField = getSpecificField()
		dtRangeForUsrSqlStr =  "(" + getAllWeekSql(from, to) + ") tmp1"			
		teSqlStr = "(" + teQuery + ") tmp2"
		
		query = "select tmp3.user_id as user_id , tmp3.spent_on as spent_on, tmp3.#{spField} as #{spField}, tmp3.status as status, tmp3.status_updater as status_updater, tmp3.created_on as created_on from (select tmp1.id as user_id, tmp1.created_on, tmp1.selected_date as spent_on, " + 
				"case when tmp2.#{spField} is null then 0 else tmp2.#{spField} end as #{spField}, " +
				"case when tmp2.status is null then 'e' else tmp2.status end as status, tmp2.status_updater "
		query = query + " from " + dtRangeForUsrSqlStr + " left join " + teSqlStr
		query = query + " on tmp1.id = tmp2.user_id and tmp1.selected_date = tmp2.spent_on where tmp1.id in (#{ids})) tmp3 "
		query = query + " left outer join (select min( #{getDateSqlString('t.spent_on')} ) as min_spent_on, t.user_id as usrid from time_entries t, users u "
		query = query + " where u.id = t.user_id and u.id in (#{ids}) group by t.user_id ) vw on vw.usrid = tmp3.user_id "
		query = query + " left join users AS un on un.id = tmp3.user_id "
		query = query + getWhereCond(status)
	end
	
	def findBySql(query)		
		spField = getSpecificField()
		result = TimeEntry.find_by_sql("select count(*) as id from (" + query + ") as v2")
		@entry_count = result.blank? ? 0 : result[0].id
        setLimitAndOffset()		
		rangeStr = formPaginationCondition()
		
		@entries = TimeEntry.find_by_sql(query + rangeStr )
		@unit = nil
		result = TimeEntry.find_by_sql("select sum(v2." + spField + ") as " + spField + " from (" + query + ") as v2")		
		@total_hours = result.blank? ? 0 : result[0].hours
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
	
	# def findIssueVwEntries
		# issueUsersCFId = getSettingCfId('wktime_additional_assignee') #22#getSettingCfId(settingId)
		# sqlStr = "select i.id as issue_id, i.subject as issue_name, i.project_id, i.assigned_to_id, 
			# p.name as project_name, ap.id as account_project_id, ap.parent_id, ap.parent_type,
			# te.id as time_entry_id, te.id, COALESCE(te.spent_on,'#{@selectedDate}') as spent_on , COALESCE(te.hours,0) as hours, te.activity_id, te.comments, te.spent_on_time, 
			# te.spent_for_id, te.spent_for_type, te.spent_id, te.spent_type from issues i 
			# inner join projects p on (p.id = i.project_id and project_id in (#{@projectId}))
			# inner join custom_values cv on (i.id = cv.customized_id and cv.customized_type = 'Issue' and cv.custom_field_id = #{issueUsersCFId} and cv.value = '#{@user.id}') OR i.assigned_to_id = #{@user.id}
			# left outer join wk_account_projects ap on (ap.project_id = p.id)
			# left outer join (select t.*, sf.spent_on_time, sf.spent_for_id, sf.spent_for_type, sf.spent_id, sf.spent_type  from time_entries t 
			# inner join wk_spent_fors sf on (t.id = sf.spent_id and sf.spent_type = 'TimeEntry' and t.spent_on = '#{@selectedDate}')) te on te.issue_id = i.id and te.user_id = #{@user.id}
			# and te.spent_for_type = ap.parent_type and te.spent_for_id = ap.parent_id" 
			# #time_entries te on te.spent_on = '#{@selectedDate}' and te.issue_id = i.id and te.user_id = #{@user.id} 
			# #left outer join wk_spent_fors sf on sf.spent_type = 'TimeEntry' and sf.spent_for_type = ap.parent_type and sf.spent_for_id = ap.parent_id
		# #sqlStr = sqlStr + " Where "
		# TimeEntry.find_by_sql(sqlStr)
	# end
	
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
		 @test = WkMailer.sendRejectionEmail(User.current,@user,@wktime,unitLabel,unit).deliver
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
		elsif !session[:wktimes].blank?
			selected_proj_id = session[:controller_name].try(:[], :project_id)
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
	
	def getTrackerbyIssue(issue_id)
		result = Issue.where(['id = ?',issue_id]) if !issue_id.blank?
		tracker = !result.blank? ? (result[0].blank? ? '0' : result[0].tracker_id if !result.blank?) : '0'
		tracker
	end
	
	def set_filter_session
		session[controller_name] = {:filters => @query.blank? ? nil : @query.filters} if session[controller_name].nil?
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
	
	def getStatusFromSession
		session[controller_name].try(:[], :status)
	end
	
	def setUserIdsInSession(ids)
		session[controller_name][:all_user_ids] = ids
	end
	
	def getUserIdsFromSession
		session[controller_name].try(:[], :all_user_ids)
	end
end