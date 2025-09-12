module LoadPatch
	class WktimeHook < Redmine::Hook::ViewListener

		def view_timelog_edit_form_bottom(context={ })
			showWarningMsg(context[:request],context[:time_entry].user_id, true)
		end

		def view_issues_edit_notes_bottom(context={})
			showWarningMsg(context[:request], User.current.id, false)
		end

		def showWarningMsg(req, user_id, log_time_page)
			wktime_helper = Object.new.extend(WktimeHelper)
			host_with_subdir = wktime_helper.getHostAndDir(req)
			"<div id='divError'>
				<font color='red'></font>
			</div>
			<input type='hidden' id='getstatus_url' value='#{url_for(:controller => 'wktime', :action => 'get_status', :host => host_with_subdir, :only_path => true, :user_id => user_id)}'>
			<input type='hidden' id='getissuetracker_url' value='#{url_for(:controller => 'wktime', :action => 'get_tracker', :host => host_with_subdir, :only_path => true)}'>
			<input type='hidden' id='log_time_page' value='#{log_time_page}'>
			<input type='hidden' id='label_issue_warn' value='#{l(:label_warning_wktime_issue_tracker)}'>
			<input type='hidden' id='label_time_warn' value='#{l(:label_warning_wktime_time_entry)}'>"
		end

		def controller_issues_edit_before_save(context={})
			if !context[:time_entry].blank?
				if !context[:time_entry].hours.blank? && !context[:time_entry].activity_id.blank?
					wktime_helper = Object.new.extend(WktimeHelper)
					status= wktime_helper.getTimeEntryStatus(context[:time_entry].spent_on,context[:time_entry].user_id)
					if !status.blank? && ('a' == status || 's' == status || 'l' == status)
						raise "#{l(:label_warning_wktime_time_entry)}"
					end
				end
			end
		end
		render_on :view_layouts_base_content, :partial => 'wktime/attendance_widget'
		render_on :view_timelog_edit_form_bottom, :partial => 'wklogmaterial/log_material'
		render_on :view_issues_form_details_bottom, :partial => 'wkissues/wk_issue_fields'

		def controller_issues_edit_before_save(context={})
			saveErpmineIssues(context[:issue], context[:params][:erpmineissues])
			saveErpmineIssueAssignee(context[:issue], context[:issue][:project_id], context[:params][:wk_issue_assignee])
		end

		def controller_issues_new_before_save(context={})
			saveErpmineIssues(context[:issue], context[:params][:erpmineissues])
			saveErpmineIssueAssignee(context[:issue], context[:issue][:project_id], context[:params][:wk_issue_assignee])
		end

		def saveErpmineIssues(issueObj, issueParm)
			issueObj.erpmineissues.safe_attributes = issueParm
		end

		def saveErpmineIssueAssignee(issueObj, projectId, userIdArr)
			assigneeAttributes = Array.new
			# userIdArr.each do |userId|
				# assigneeAttributes << {user_id: userId.to_i, project_id: projectId}
			# end
			# issueObj.assignees_attributes = assigneeAttributes
			WkIssueAssignee.where(:issue_id => issueObj.id).where.not(:user_id => userIdArr).delete_all()
			unless userIdArr.blank?
				userIdArr.collect{ |id|
					iscount = WkIssueAssignee.where("issue_id = ? and user_id = ? ", issueObj.id, id).count
					unless iscount > 0
						assigneeAttributes << {user_id: id.to_i, project_id: projectId}
					end
				}
			end
			issueObj.assignees_attributes = assigneeAttributes
		end

		render_on :view_issues_show_description_bottom, :partial => 'wkissues/show_wk_issues'
		render_on :view_layouts_base_html_head, :partial => 'wkbase/base_header'
		render_on :view_projects_form, :partial => 'wkproject/project_settings'

	end
end