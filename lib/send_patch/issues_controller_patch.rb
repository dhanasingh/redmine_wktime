module SendPatch::IssuesControllerPatch
	def self.included(base)
		base.class_eval do

			def destroy
				raise Unauthorized unless @issues.all?(&:deletable?)

				# all issues and their descendants are about to be deleted
				issues_and_descendants_ids = Issue.self_and_descendants(@issues).pluck(:id)
				time_entries = TimeEntry.where(:issue_id => issues_and_descendants_ids)
				@hours = time_entries.sum(:hours).to_f

				# ============= ERPmine_patch Redmine 6.1 =====================
				expense_entries = WkExpenseEntry.where(:issue_id => issues_and_descendants_ids)
				@amount = expense_entries.sum(:amount).to_f

				#for material and resident entry update
				material_entries = WkMaterialEntry.where(:issue_id => issues_and_descendants_ids)
				@quantity = material_entries.sum(:quantity).to_f

				if @hours > 0 || @amount > 0 || @quantity > 0 # added check for expense, material and resident entry

					# Check for the submitted or approve time and expense entries
					# show error message when there is a submitted time or expense entry
					# if part wrote by us and else part has expense destroy wrote by us

					wktime_helper = Object.new.extend(WktimeHelper)
					issue_id = @issues.map(&:id)
					ret = wktime_helper.get_status_Project_Issue(issue_id[0],nil)
					if ret
						flash.now[:error] = l(:error_project_issue_associate)
						return
					else
					# =============================================================
						case params[:todo]
						when 'destroy'
						# nothing to do
						when 'nullify'
              if Setting.timelog_required_fields.include?('issue_id')
                flash.now[:error] = l(:field_issue) + " " + ::I18n.t('activerecord.errors.messages.blank')
                return
              else
                time_entries.update_all(:issue_id => nil)
                # ============= ERPmine_patch Redmine 6.1 ===========
                expense_entries.update_all(:issue_id => nil)
                material_entries.update_all(:issue_id => nil) #for material and resident entry update
                # ==============================================
						  end
						when 'reassign'
              reassign_to = @project && @project.issues.find_by_id(params[:reassign_to_id])
              if reassign_to.nil?
                flash.now[:error] = l(:error_issue_not_found_in_project)
                return
              elsif issues_and_descendants_ids.include?(reassign_to.id)
                flash.now[:error] = l(:error_cannot_reassign_time_entries_to_an_issue_about_to_be_deleted)
                return
              else
                time_entries.update_all(:issue_id => reassign_to.id, :project_id => reassign_to.project_id)
                # ============= ERPmine_patch Redmine 6.1 ===========
                expense_entries.update_all(:issue_id => reassign_to.id, :project_id => reassign_to.project_id)

                #for material and resident entry update
                material_entries.update_all(:issue_id => reassign_to.id, :project_id => reassign_to.project_id)
                # ==============================================
              end
            else
              # display the destroy form if it's a user request
              return unless api_request?
            end
          # ============= ERPmine_patch Redmine 6.1 ===========
					end
          # ==============================================
				end
				@issues.each do |issue|
					begin
					  issue.reload.destroy
					rescue ::ActiveRecord::RecordNotFound # raised by #reload if issue no longer exists
					  # nothing to do, issue was already deleted (eg. by a parent)
					end
				end
				respond_to do |format|
					format.html do
						flash[:notice] = l(:notice_successful_delete)
						redirect_back_or_default _project_issues_path(@project)
					end
          format.api  {render_api_ok}
				end
			end
		end
	end
end