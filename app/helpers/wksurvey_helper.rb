module WksurveyHelper
	include WktimeHelper

  def getSurveyStatusArr
	{
		"" => '',
		l(:label_new) => 'N',
		l(:label_open) => 'O',
		l(:label_close) => 'C',
		l(:label_archived) => 'A'
	}
  end

  def getQuestionType
	{
		l(:label_check_box) => 'CB',
		l(:label_radio_button) => 'RB',
		l(:label_text_box) => 'TB',
		l(:label_text_area) => 'MTB'
	}
	end
	
	def getUserGroup
		
		groupNames = Hash.new
		groupNames[''] = ''
		(Group.sorted.all).each do |group| 
			groupNames[group.name] = group.id
		end
		groupNames
	end

  def getSurveyFor
		{
			"" => '',
			l(:label_project) => 'Project',
			l(:label_accounts) => 'Accounts',
			l(:label_contact) => 'Contact'
		}
  end

  def isStatusNew(status)
		ret = false
		if status != 'N'
			ret = true
		end
		ret
	end

	def checkEditSurveyPermission
		validateERPPermission("E_SUR")
	end 
	
	def surveyList(params)

		surveys = get_survey_with_userGroup
		unless params[:survey_name].blank?
			surveys = surveys.where("LOWER(name) LIKE lower('%#{params[:survey_name]}%')")
		end

		unless params[:status].blank?
			surveys = surveys.where(:status => params[:status])
		end

		getSurveyForType(params)
		surveys = surveys.where(survey_for_type: @surveyForType, survey_for_id: [nil, @surveyForID])
		surveys = surveys.where(status: ["O", "C"]) unless params[:isIssue].blank?
        surveys
	end
	
	def get_survey_with_userGroup
		if checkEditSurveyPermission
			WkSurvey.all
		else
			WkSurvey.joins("LEFT JOIN groups_users ON groups_users.group_id = wk_surveys.group_id")
			.where("status IN ('O', 'C') AND (groups_users.user_id =" + (User.current.id).to_s + " OR wk_surveys.group_id IS NULL)")
		end
	end
	
	def get_survey_url(urlHash, params, redirect)

		if !params[:project_id].blank?
			urlHash[:project_id] = params[:project_id]
		elsif !params[:contact_id].blank?
			urlHash[:contact_id] = params[:contact_id]
			if redirect
				urlHash[:controller] = "wkcrmcontact" 
				urlHash[:action] = 'edit'
			end
		elsif !params[:account_id].blank?
			urlHash[:account_id] = params[:account_id]
			if redirect
				urlHash[:controller] = "wkcrmaccount"
				urlHash[:action] = 'edit'
			end
		end

		if !params[:issue_id].blank? && redirect
			urlHash = Hash.new
			urlHash[:controller] = "issues"
			urlHash[:action] = 'show'
			urlHash[:id] = params[:issue_id]
		elsif !params[:issue_id].blank?
			urlHash[:issue_id] = params[:issue_id]
		end
		urlHash
	end

	def get_project_id(params)
		project_id = (Project.where(:identifier  => params[:project_id])).first
		project_id.id
	end

	def getSurveyForType(params)

		if !params[:issue_id].blank? && params[:isIssue].blank?
			@surveyForType = "Issues"
			@surveyForID = params[:issue_id]
		elsif !params[:project_id].blank?
			@surveyForType = "Project"
			@surveyForID = get_project_id(params)
		elsif !params[:contact_id].blank?
			@surveyForType = "Contact"
			@surveyForID = params[:contact_id]
		elsif !params[:account_id].blank?
			@surveyForType = "Accounts"
			@surveyForID = params[:account_id]
		else
			@surveyForType = nil
			@surveyForID = nil
		end
	end
end
