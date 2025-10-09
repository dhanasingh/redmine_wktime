module SendPatch::ProjectsControllerPatch
	def self.included(base)
		base.class_eval do
			def create
				@issue_custom_fields = IssueCustomField.sorted.to_a
				@trackers = Tracker.sorted.to_a
				@project = Project.new
				@project.safe_attributes = params[:project]

				if @project.save
					# ============= ERPmine_patch Redmine 6.1 =====================
					 @project.erpmineproject.safe_attributes = params[:erpmineproject]
					 @project.erpmineproject.save
					# =============================
				  unless User.current.admin?
						@project.add_default_member(User.current)
				  end
				  respond_to do |format|
						format.html do
							flash[:notice] = l(:notice_successful_create)
							if params[:continue]
								attrs = {:parent_id => @project.parent_id}.compact
								redirect_to new_project_path(attrs)
							else
								redirect_to settings_project_path(@project)
							end
						end
						format.api do
							render(
								:action => 'show',
								:status => :created,
								:location => url_for(:controller => 'projects',
																		 :action => 'show', :id => @project.id)
							)
						end
				  end
				else
				  respond_to do |format|
						format.html {render :action => 'new'}
						format.api  {render_validation_errors(@project)}
				  end
				end
			end

			def update
				@project.safe_attributes = params[:project]
				if @project.save
					# ============= ERPmine_patch Redmine 6.1 =====================
					 @project.erpmineproject.safe_attributes = params[:erpmineproject]
					 @project.erpmineproject.save
					# =============================
					respond_to do |format|
						format.html do
							flash[:notice] = l(:notice_successful_update)
							redirect_to settings_project_path(@project, params[:tab])
						end
						format.api {render_api_ok}
					end
				else
					respond_to do |format|
						format.html do
							settings
							render :action => 'settings'
						end
						format.api {render_validation_errors(@project)}
					end
				end
			end

		  def destroy
				unless @project.deletable?
					deny_access
					return
				end

			 	@project_to_destroy = @project
				if api_request? || params[:confirm] == @project_to_destroy.identifier
				# ============= ERPmine_patch Redmine 6.1 =====================
					wktime_helper = Object.new.extend(WktimeHelper)
					ret = wktime_helper.get_status_Project_Issue(nil,@project_to_destroy.id)
					if ret
						#render_403
						#return false
						flash.now[:error] = l(:error_project_issue_associate)
						return
					else
						WkExpenseEntry.where(['project_id = ?', @project_to_destroy.id]).delete_all
				# =============================
						DestroyProjectJob.schedule(@project_to_destroy)
						flash[:notice] = l(:notice_successful_delete)
						respond_to do |format|
							format.html do
								redirect_to(
									User.current.admin? ? admin_projects_path : projects_path
								)
							end
							format.api  {render_api_ok}
						end
					end
				end
				# hide project in layout
				@project = nil
		  end
	  end
	end
end