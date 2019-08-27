module WksurveyHelper

    include WktimeHelper

    def getSurveyStatus
        {
            "" => '',
            l(:label_new) => 'N',
            l(:label_open) => 'O',
            l(:label_closed) => 'C',
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
        survey_types = {
            "" => '',
            l(:label_project) => 'Project',
            l(:label_accounts) => 'WkAccount',
            l(:label_contact) => 'WkCrmContact',
            l(:label_user) => 'User'
        }
        call_hook(:add_survey_for, :survey_types => survey_types)
        survey_types
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
        if !params[:survey_for].blank? || (@surveyForID.blank? && !@surveyForType.blank?)
            survey_for = !params[:survey_for].blank? ? params[:survey_for] : @surveyForType
            surveys = surveys.where(survey_for_type: survey_for)
        else
            surveys = surveys.where(survey_for_type: @surveyForType, survey_for_id: [nil, @surveyForID])
            surveys = surveys.where(status: ["O", "C"]) unless params[:isIssue].blank?
        end
        surveys
    end

    def get_survey_with_userGroup(survey_id)
        if checkEditSurveyPermission && survey_id.blank?
            survey = WkSurvey.all
        else
            survey = WkSurvey.joins("INNER JOIN(
                SELECT wk_surveys.id, count(wk_surveys.id) FROM wk_surveys
                LEFT JOIN groups_users ON groups_users.group_id = wk_surveys.group_id
                LEFT JOIN users ON users.id = groups_users.user_id 
                WHERE wk_surveys.status IN ('O', 'C') AND (groups_users.user_id = #{(User.current.id).to_s}
                    OR wk_surveys.group_id IS NULL OR (users.parent_id = #{(User.current.id).to_s}
                    AND wk_surveys.is_review IS TRUE) OR true = #{validateERPPermission("E_SUR")})
                GROUP BY wk_surveys.id
                ) AS S ON S.id = wk_surveys.id")
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
            project_name = get_project_name(urlHash[:surveyForID].to_i)
            urlHash = Hash.new
            urlHash[:project_id] = project_name
            urlHash[:controller] = "wksurvey"
        elsif urlHash[:surveyForType] == "Issue" && !urlHash[:surveyForID].blank?
            surveyForID = urlHash[:surveyForID]
            urlHash = Hash.new
            urlHash[:controller] = "issues"
            urlHash[:action] = 'show'
            urlHash[:id] = params[:issue_id].blank? ? surveyForID : params[:issue_id]
        else
            urlHash[:controller] = "wksurvey"
            urlHash[:action] = 'index'
        end
        call_hook(:get_survey_redirect_url, urlHash: urlHash, params: params)
        urlHash
    end

    def get_survey_url(urlHash, params, method)
        urlHash[:controller] = "wksurvey"
        urlHash[:action] = method
        call_hook(:get_survey_url, urlHash: urlHash, params: params)

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
        surveyFor = Hash.new
        call_hook(:getSurveyForType, surveyFor: surveyFor, params: params)

        if !surveyFor.blank?
            @surveyForType = surveyFor[:surveyForType]
            @surveyForID = surveyFor[:surveyForID]
        elsif (!params[:issue_id].blank? && params[:isIssue].blank?) || params[:surveyForType] == "Issue"
            @surveyForType = "Issue"
            @surveyForID = params[:issue_id].blank? ? params[:surveyForID] : params[:issue_id]
        elsif !params[:project_id].blank? || params[:surveyForType] == "Project"
            @surveyForType = "Project"
            @surveyForID = params[:project_id].blank? ? params[:surveyForID] : get_project_id(params[:project_id])
        elsif !params[:contact_id].blank? || params[:surveyForType] == "WkCrmContact"
            @surveyForType = "WkCrmContact"
            @surveyForID = params[:contact_id].blank? ? params[:surveyForID] : params[:contact_id]
        elsif !params[:account_id].blank? || params[:surveyForType] == "WkAccount"
            @surveyForType = "WkAccount"
            @surveyForID = params[:account_id].blank? ? params[:surveyForID] : params[:account_id]
        elsif params[:surveyForType] == 'User' || params[:surveyForType] == "User"
            @surveyForType = "User"
            @surveyForID = User.current.id
        else
            survey_for = params[:surveyForType].blank? ? params[:survey_for] : params[:surveyForType]
            @surveyForType = survey_for.blank? ? nil : survey_for
            @surveyForID = nil
        end
        if surveyFor.blank?
            surveyFor[:surveyForType] = @surveyForType
            surveyFor[:surveyForID] = @surveyForID
        end
        surveyFor
    end

    def getResponseStatus
        {
            l(:label_open) => 'O',
            l(:label_closed) => 'C',
            l(:label_reviewed) => 'R'
        }
    end
end
