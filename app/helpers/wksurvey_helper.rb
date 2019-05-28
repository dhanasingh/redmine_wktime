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
            l(:label_accounts) => 'WkAccount',
            l(:label_contact) => 'WkCrmContact',
            l(:label_user) => 'User'
        }
    end

    def checkEditSurveyPermission
        validateERPPermission("E_SUR")
    end 

    def surveyList(params)

        surveys = get_survey_with_userGroup(nil)
        unless params[:survey_name].blank?
            surveys = surveys.where("LOWER(name) LIKE lower('%#{params[:survey_name]}%')")
        end

        unless params[:status].blank?
            surveys = surveys.where(:status => params[:status])
        end

        getSurveyForType(params)
        unless params[:survey_for].blank?
            surveys = surveys.where(survey_for_type: params[:survey_for])
        else
            surveys = surveys.where(survey_for_type: @surveyForType, survey_for_id: [nil, @surveyForID])
            surveys = surveys.where(status: ["O", "C"]) unless params[:isIssue].blank?
            surveys
        end
    end

    def get_survey_with_userGroup(survey_id)
        if checkEditSurveyPermission && survey_id.blank?
            survey = WkSurvey.all
        else
            survey = WkSurvey.joins("LEFT JOIN groups_users ON groups_users.group_id = wk_surveys.group_id")
            .where("status IN ('O', 'C') AND (groups_users.user_id =" + (User.current.id).to_s + " OR wk_surveys.group_id IS NULL)")
        end
        survey = survey.where(:id => survey_id) unless survey_id.blank?
        survey
    end

    def get_survey_redirect_url(urlHash, params)
        if urlHash[:surveyForType] == "WkAccount" && !urlHash[:surveyForID].blank?
            urlHash[:controller] = "wkcrmaccount"
            urlHash[:action] = 'edit'
            urlHash[:account_id] = urlHash[:surveyForID]
        elsif urlHash[:surveyForType] == "WkCrmContact" && !urlHash[:surveyForID].blank?
            urlHash[:controller] = "wkcrmcontact"
            urlHash[:action] = 'edit'
            urlHash[:contact_id] = urlHash[:surveyForID]
        elsif urlHash[:surveyForType] == "User"
            urlHash[:controller] = "wksurvey"
            urlHash[:action] = 'user_survey'
            urlHash[:tab] = 'wksurvey'
        elsif urlHash[:surveyForType] == "Project" && !urlHash[:surveyForID].blank?
            urlHash = Hash.new
            urlHash[:project_id] = get_project_name(params[:survey_for_id])
            urlHash[:controller] = "wksurvey"
        elsif urlHash[:surveyForType] == "Issue" && !urlHash[:surveyForID].blank?
            urlHash = Hash.new
            urlHash[:controller] = "issues"
            urlHash[:action] = 'show'
            urlHash[:issue_id] = params[:issue_id]
        else
            urlHash[:controller] = "wksurvey"
            urlHash[:action] = 'index'
        end
        urlHash
    end

    def get_survey_url(urlHash, params, method)
        urlHash[:controller] = "wksurvey"
        urlHash[:action] = method
        if urlHash[:surveyForType] == "WkAccount"
            urlHash[:surveyForID] = params[:account_id] if urlHash[:surveyForID].blank?
        elsif urlHash[:surveyForType] == "WkCrmContact"
            urlHash[:surveyForID] = params[:contact_id] if urlHash[:surveyForID].blank?
        elsif urlHash[:surveyForType] == "User"
            urlHash[:surveyForID] = params[:user_id].blank? ? User.current.id : params[:user_id]  if urlHash[:surveyForID].blank?
        elsif params[:isIssue]
            urlHash[:surveyForID] = params[:issue_id]
            urlHash[:surveyForType] = "Issue"
        elsif urlHash[:surveyForType] == "Project"
            urlHash[:surveyForID] = get_project_id(params[:project_id]) if urlHash[:surveyForID].blank?
        end
        urlHash
    end

    def get_project_id(project_name = params[:project_id])
        project_id = (Project.where(:identifier  => project_name)).first
        project_id = project_id.id unless project_id.blank?
        project_id
    end

    def get_project_name(id)
        project_name = (Project.where(:id => id)).first
        project_name.identifier unless project_name.blank?
        project_name
    end

    def getSurveyForType(params)

        if !params[:issue_id].blank? && params[:isIssue].blank?
            @surveyForType = "Issue"
            @surveyForID = params[:issue_id]
        elsif !params[:project_id].blank?
            @surveyForType = "Project"
            @surveyForID = get_project_id(params[:project_id])
        elsif !params[:contact_id].blank?
            @surveyForType = "WkCrmContact"
            @surveyForID = params[:contact_id]
        elsif !params[:account_id].blank?
            @surveyForType = "WkAccount"
            @surveyForID = params[:account_id]
        elsif params[:surveyForType] == 'User'
            @surveyForType = "User"
            @surveyForID = User.current.id
        else
            @surveyForType = nil
            @surveyForID = nil
        end
    end
end
