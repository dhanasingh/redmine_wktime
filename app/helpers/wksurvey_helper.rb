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

module WksurveyHelper

  include WktimeHelper

  def getSurveyStatus
    {
        "" => '',
        l(:label_new) => 'N',
        l(:label_open) => 'O',
        l(:field_closed_on) => 'C',
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
    points = showSurveyPoints(params,nil)
    if points[:id].present?
      surveys = surveys.with_total_points(points[:id].to_i)
    end
    surveys
  end

  def get_survey_with_userGroup(survey_id, checkSurveyPerm = true)
    if checkEditSurveyPermission && survey_id.blank?
        survey = WkSurvey.all
    else
		  groups_users_comp = call_hook(:add_comp_filter, table: 'groups_users', comp_id: @comp_id ) || ""
		  surveys_comp = call_hook(:add_comp_filter, table: 'wk_surveys', comp_id: @comp_id ) || ""
		  users_comp = call_hook(:add_comp_filter, table: 'users', comp_id: @comp_id ) || ""
        users = convertUsersIntoString()
        survey = WkSurvey.joins("INNER JOIN (
            SELECT wk_surveys.id, count(wk_surveys.id) count FROM wk_surveys
            LEFT JOIN groups_users ON groups_users.group_id = wk_surveys.group_id " +
            " LEFT JOIN users ON users.id = groups_users.user_id " + get_comp_cond('users') +
            " WHERE wk_surveys.status IN ('O', 'C') AND (groups_users.user_id = #{User.current.id} OR wk_surveys.group_id IS NULL)
                OR (#{booleanFormat(checkSurveyPerm)} = #{booleanFormat(true)} AND is_review = #{booleanFormat(true)} AND users.id IN (#{users})) " + get_comp_cond('wk_surveys') +
            " GROUP BY wk_surveys.id
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

    if surveyFor.present?
      @surveyForType = surveyFor[:surveyForType]
      @surveyForID = surveyFor[:surveyForID]
    elsif (params[:issue_id].present? && params[:isIssue].blank?) || params[:surveyForType] == "Issue"
      @surveyForType = "Issue"
      @surveyForID = params[:issue_id] || params[:surveyForID]
    elsif params[:project_id].present? || params[:surveyForType] == "Project"
      @surveyForType = "Project"
      @surveyForID = get_project_id(params[:project_id]) || params[:surveyForID]
    elsif params[:contact_id].present? || params[:surveyForType] == "WkCrmContact" || @survey&.survey_for_type == "WkCrmContact"
      @surveyForType = "WkCrmContact"
      @surveyForID = params[:contact_id] || params[:surveyForID]
    elsif params[:account_id].present? || params[:surveyForType] == "WkAccount" || @survey&.survey_for_type == "WkAccount"
      @surveyForType = "WkAccount"
      @surveyForID = params[:account_id] || params[:surveyForID]
    elsif params[:surveyForType] == "User" || @survey&.survey_for_type == "User"
      @surveyForType = "User"
      @surveyForID = User.current.id
    else
      @surveyForType = params[:surveyForType] || (params[:survey_for].present? ?  params[:survey_for] : nil)
      @surveyForID = nil
    end
    {surveyForType: @surveyForType, surveyForID: @surveyForID}
  end

  def getResponseStatus
    {
        l(:label_open) => 'O',
        l(:field_closed_on) => 'C',
        l(:label_reviewed) => 'R'
    }
  end

  def sent_emails(subject, language, email_id, emailNotes, ccMailId = [])
    begin
      WkMailer.email_user(subject, language, email_id, emailNotes, ccMailId).deliver
    rescue Exception => e
      errMsg = (e.message).to_s
    end
    errMsg
  end

  def getResponseGroup(survey_id=params[:survey_id])
    closedResponses = WkSurveyResponse.getClosedResp(survey_id)
    groupedNames = closedResponses.pluck(:group_name).compact
  end

  def getReportingUsers
    getReportUsers(User.current.id).pluck(:id)
  end

  def convertUsersIntoString
    users = getReportingUsers << User.current.id
    users = users.join(',')
  end

  def validateTrendingChart(survey_id=params[:survey_id], question_id=params[:question_id])
    showTrendingChart = true
    choices = WkSurvey.getSurveyChoices(survey_id, question_id)
    choices.each {|choice| showTrendingChart = false if !is_numeric? choice.name}
    showTrendingChart
  end

  def is_numeric?(obj)
    obj.to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/) != nil
  end

  def get_Graph_data(question_id=nil)
    question_id ||= params[:question_id]
    if params[:groupName] == 'trendChart'
      wkquestionAvg = WkSurvey.surveyAvgQuestion(params[:survey_id], question_id)
      questionAvg = wkquestionAvg.map{|e| (e.questionavg || 0).to_f}
      questionLabels = wkquestionAvg.map{|e| e.grpname}

      data = {
        :labels => questionLabels,
        :average => questionAvg,
        :graphtype => "line"
      }
    else

      if params[:surveyForID].blank? && params[:surveyForType].blank?
        surveyForQry = " AND SR.survey_for_type IS NULL AND SR.survey_for_id IS NULL "
      elsif params[:surveyForType].present? && params[:surveyForID].blank? || params[:surveyForType] == 'User'
        surveyForQry = " AND SR.survey_for_type = '#{params[:surveyForType]}' "
      else
        surveyForQry = " AND SR.survey_for_type = '#{params[:surveyForType]}' AND SR.survey_for_id = #{params[:surveyForID]} "
      end

      groupNameCond = ""
      if @survey.recur?
        if params[:groupName].present?
          groupNameCond = " AND group_name = '#{params[:groupName]}' "
        elsif params[:groupName].blank? && (validateERPPermission("E_SUR"))
          groupNameCond = " AND group_name IS NULL "
        else
          groupNameCond = " AND group_name = '#{getResponseGroup.last}' "
        end
      end

      question_choices = WkSurvey.find_by_sql("SELECT SC.name, SC.id
        FROM wk_surveys AS S
        INNER JOIN wk_survey_questions AS SQ ON S.id = SQ.survey_id
        INNER JOIN wk_survey_choices AS SC ON SC.survey_question_id = SQ.id
        WHERE SQ.id = #{question_id} " + get_comp_cond('S') + get_comp_cond('SQ') + get_comp_cond('SC') + " ORDER BY SC.id")

      if question_choices.length > 0
        surveyed_employees_per_choice = WkSurvey.find_by_sql("SELECT COUNT(SR.user_id) AS emp_count, SC.id
          FROM wk_surveys AS S
          INNER JOIN wk_survey_questions AS SQ ON S.id = SQ.survey_id
          INNER JOIN wk_survey_choices AS SC ON SQ.id = SC.survey_question_id
          INNER JOIN wk_survey_answers AS SCC ON SC.id = SCC.survey_choice_id
          INNER JOIN wk_survey_responses AS SR ON SR.survey_id = S.id	AND SR.id = SCC.survey_response_id " +
          " WHERE SQ.id = #{question_id} "+ surveyForQry + groupNameCond + get_comp_cond('S') + get_comp_cond('SQ') + get_comp_cond('SC') + get_comp_cond('SCC') + get_comp_cond('SR') +
          "GROUP BY S.id, SQ.id, SC.id
          ORDER BY SC.id")
      else
        surveyed_employees_per_choice = WkSurvey.find_by_sql("SELECT COUNT(SR.user_id) AS emp_count, SQ.id
        FROM wk_surveys AS S
        INNER JOIN wk_survey_questions AS SQ ON S.id = SQ.survey_id
        INNER JOIN wk_survey_answers AS SCC ON SQ.id = SCC.survey_question_id
        INNER JOIN wk_survey_responses AS SR ON SR.survey_id = S.id	AND SR.id = SCC.survey_response_id " +
        " WHERE SQ.id = #{question_id} "+ surveyForQry + groupNameCond + get_comp_cond('S') + get_comp_cond('SQ') + get_comp_cond('SCC') + get_comp_cond('SR') +
        "GROUP BY S.id, SQ.id")
      end

      fields = Array.new
      if question_choices.length > 0
        question_choices.each {|choice| fields << choice.name}
      else
        fields << WkSurveyQuestion.question_name(question_id) || ''
      end

      sel_choices = Hash.new
      surveyed_employees_per_choice.each do |choice|
        sel_choices[choice.id] = choice.emp_count
      end
      employees_per_choice = Array.new
      totalScore = 0

      if question_choices.length > 0
        question_choices.each do |choice|
          employees_per_choice << (sel_choices[choice.id].blank? ? 0 : sel_choices[choice.id])
          totalScore += choice.name.to_i * sel_choices[choice.id].to_i if validateTrendingChart(@survey.id, question_id)
        end
      else
        employees_per_choice << (sel_choices[question_id.to_i].blank? ? 0 : sel_choices[question_id.to_i])
      end

      avgScore = 0
      if validateTrendingChart(@survey.id, question_id)
        avgScore = totalScore / employees_per_choice.inject(0, :+).to_f
      end

      data = {
        :labels => fields,
        :emp_count_per_choices => employees_per_choice,
        :avg_score => avgScore.round(2),
        :showAvg => validateTrendingChart(@survey.id, question_id)
      }
    end
    data
  end

  def get_response_group_items
    response_grp = getResponseGroup.reverse
    if response_grp.length > 0
      response_grp.unshift(["",""]) if validateERPPermission("E_SUR")
      response_grp << [l(:label_trend_chart), "trendChart"]
    end
    response_grp
  end

  def showSurveyPoints(params, survey_id = nil)
    survey_points = { show_points: false }

    survey_points_data = call_hook(:survey_points, params: params)
    if survey_points_data.present?
      points = survey_points_data.is_a?(Array) ? survey_points_data.first : survey_points_data
      survey_points[:id] = eval(points) if points.is_a?(String)
      survey_points[:show_points] = true if points.is_a?(String)
    end

    if survey_points[:id].blank? && survey_id.present?
      survey = WkSurvey.find_by(id: survey_id)
      survey_points[:show_points] = survey&.use_points?
    end
    
    survey_points
  end

  def getSurveyLabel(params)
    survey_label = {}
    label = call_hook(:get_survey_label, {params: params})
		unless label.blank?
      mergeHash = eval(label)
      survey_label =  survey_label.merge(mergeHash)
		end
    survey_label
  end

  def showSurveyLink(params, entry)
    type = getSurveyForType(params)
    showLink = call_hook(:show_survey_link, {type: type, params: params})
		!to_boolean(showLink)
  end
end
