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
			l(:label_issue) => 'Issue',
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

		unless params[:project_id].blank?
			project_id = (Project.where(:identifier  => params[:project_id])).first
			surveys = surveys.where("(survey_for_type = 'Project' AND survey_for_id = ?) OR (survey_for_type = 'Project' AND survey_for_id IS NULL)", project_id.id)
		end

		unless params[:survey_name].blank?
			surveys = surveys.where("LOWER(name) LIKE lower('%#{params[:survey_name]}%')")
		end

		unless params[:status].blank?
			surveys = surveys.where(:status => params[:status])
		end

		unless params[:filter_group_id].blank?
			surveys = surveys.where(:group_id => params[:filter_group_id])
		end

		unless params[:contact_id].blank?
			surveys = surveys.where("(survey_for_type = 'Contact' AND survey_for_id = ?) OR (survey_for_type = 'Contact' AND survey_for_id IS NULL)", params[:contact_id])
		end

		unless params[:account_id].blank?
			surveys = surveys.where("(survey_for_type = 'Accounts' AND survey_for_id = ?) OR (survey_for_type = 'Accounts' AND survey_for_id IS NULL)", params[:account_id])
		end

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
	
	def get_survey_url(action, id, params)
		urlHash = { :controller => "wksurvey", :action => action, :survey_id => id, :tab => "wksurvey" }
		if !params[:contact_id].blank?
			urlHash[:contact_id] = params[:contact_id]
		elsif !params[:account_id].blank?
			urlHash[:account_id] = params[:account_id]
		end
		urlHash
	end
end
