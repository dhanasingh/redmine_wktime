# ERPmine - ERP for service industry
# Copyright (C) 2011-2021  Adhi software pvt ltd
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

class WksurveyController < WkbaseController

  unloadable
  before_action :require_login, :survey_url_validation, :check_perm_and_redirect
  before_action :check_permission , only: "survey_response"
  accept_api_auth :index, :save_survey, :find_survey_for, :survey, :update_survey, :survey_result, :survey_response
  menu_item :wksurvey
  menu_item :wkattendance, :only => :user_survey
  include WksurveyHelper

  def index
    sort_init [["status", "desc"], ["updated_at", "desc"]]

    sort_update "survey" => "#{WkSurvey.table_name}.name",
                "status" => "#{WkSurvey.table_name}.status",
                "updated_at" => "#{WkSurvey.table_name}.updated_at"

    surveys = surveyList(params)
    surveys = surveys.reorder(sort_clause)
		respond_to do |format|
			format.html {
        @all_surveys = formPagination(surveys)
				render :layout => !request.xhr?
			}
			format.api{
        @entry_count = surveys.count
        setLimitAndOffset()
        @surveys = surveys
      }
			format.csv{
				headers = {name: l(:field_name), status: l(:field_status)}
				data = surveys.collect{|entry| {name: entry.name, status: getSurveyStatus.invert[entry.status]} }
				send_data(csv_export(headers: headers, data: data), type: "text/csv; header=present", filename: "survey.csv")
			}
		end
  end

  def edit
    @survey = nil if params[:survey_id].blank?
    @edit_Question_Entries = nil
    @edit_Choice_Entries = nil
    getSurveyForType(params)
    unless params[:survey_id].blank?
      @edit_Question_Entries = WkSurvey.joins("LEFT JOIN wk_survey_questions ON wk_survey_questions.survey_id = wk_surveys.id")
      .where(:id => params[:survey_id].to_i).select("wk_survey_questions.id AS question_id, wk_survey_questions.name AS question_name,
        wk_survey_questions.question_type, is_reviewer_only, is_mandatory, not_in_report").order("question_id")

      @edit_Choice_Entries = WkSurvey.joins("LEFT JOIN wk_survey_questions ON wk_survey_questions.survey_id = wk_surveys.id")
        .joins("LEFT JOIN wk_survey_choices ON wk_survey_questions.id = wk_survey_choices.survey_question_id")
        .where(:id => params[:survey_id].to_i)
        .select("wk_survey_questions.id AS question_id, wk_survey_choices.id AS choice_id, wk_survey_choices.name, wk_survey_choices.points")
        .order("question_id, choice_id")
    end
  end

  def save_survey
    errMsg = ""
    surveyQuestions = Array.new
    questions = Hash.new
    questionChoices = Hash.new
    params.permit!
    params[:survey_id] = params["wksurvey"]["id"] if api_request? && params["wksurvey"].present?

    if params[:survey_id].blank?
      survey = WkSurvey.new
    else
      survey = WkSurvey	.find(params[:survey_id].to_i)
    end

    if survey.status.blank? || survey.status == "N"
      if api_request? && params["wksurvey"].present?
        surveyParams = (params["wksurvey"]).to_h
        surveyParams["questions"].each do |question|
          question["wk_survey_choices_attributes"] = question["choices"]
          question.delete("choices")
        end
        surveyParams["wk_survey_questions_attributes"] = surveyParams["questions"]
        surveyParams.delete("status_label")
        surveyParams.delete("questions")
        survey.assign_attributes(surveyParams)
      else
        survey.name = params[:survey_name]
        survey.status = params[:survey_status]
        survey.group_id = params[:group_id]
        survey.recur = params[:recur].blank? ? false : params[:recur]
        survey.recur_every =  params[:recur].blank? ? nil : params[:recur_every]
        survey.survey_for_type = params[:survey_for].blank? ? nil : params[:survey_for]
        survey.is_review = params[:review].blank? ? false : params[:review]
        survey.survey_for_id = params[:survey_for_id].blank? ? nil : params[:survey_for_id]
        survey.save_allowed = params[:save_allowed] || false
        survey.hide_response = params[:hide_response] || false

        params.each do |ele_nameVal|
          #Question Array
          if ((ele_nameVal.first).include? "questionName_") && (!(ele_nameVal.last).blank?)
            question_ele = (ele_nameVal.first).split("_")
            questionID = (question_ele[1]).blank? ? nil : question_ele[1]
            qIndex = question_ele.last
            qType = params["question_type_"+qIndex]
            reviewerOnly = params["reviewerOnly_"+qIndex]
            mandatory = params["mandatory_"+qIndex]
            notInRpt = params["notInRpt_"+qIndex]
            questions[qIndex] = [questionID, qType, ele_nameVal.last, reviewerOnly.present?, mandatory.present?,
              notInRpt.present?]
          end

          if (((ele_nameVal.first).include? "questionChoices_") || ((ele_nameVal.first).include? "qpoints_") || ((ele_nameVal.first).include? "deleteChoiceIds_")) && (!(ele_nameVal.last).blank?)
            choice_ele = (ele_nameVal.first).split("_")
            # Deleted Choices Array
            if ((ele_nameVal.first).include? "deleteChoiceIds_")
              qIndex = choice_ele[1]
              deleteChoiceIds = ele_nameVal.last.split(",")
              questionChoices[qIndex] = [] if questionChoices[qIndex].blank?
              deleteChoiceIds.each do |deleteChoiceID|
                questionChoices[qIndex] << { id: deleteChoiceID, _destroy: "1"}
              end
              # Text box Questions Points Array
            elsif ((ele_nameVal.first).include? "qpoints_" )
              qIndex = choice_ele[1]
              questionChoices[qIndex] = [] if questionChoices[qIndex].blank?
              questionChoices[qIndex] << {id: nil, name: params[:survey_name], points: ele_nameVal.last } if params["allowPoints_" + qIndex] == "true"
              # Choices Array
            elsif ((ele_nameVal.first).include? "questionChoices_")
              questionChoiceID = (choice_ele[3]).blank? ? "" : choice_ele[3]
              qIndex = choice_ele[2]
              choice_points = params["points_"+ choice_ele[1] + "_" + qIndex + "_" + questionChoiceID + "_" + choice_ele[4]]
              choice_name = params["questionChoices_"+ choice_ele[1] + "_" + qIndex + "_" + questionChoiceID + "_" + choice_ele[4]]
              questionChoices[qIndex] = [] if questionChoices[qIndex].blank?
              questionChoices[qIndex] << {id: questionChoiceID, name: choice_name, points: choice_points }
            end
          end
        end

        questions.each do |question|
          questionChoice = question.first
          questionChoiceArr = questionChoices[questionChoice].blank? ? Array.new : questionChoices[questionChoice]
          surveyQuestions << {id: (question.last).first, name: (question.last)[2], question_type: ((question.last)[1].blank? ? "RB" : (question.last)[1]), is_reviewer_only: (question.last)[3], is_mandatory: (question.last)[4], not_in_report: (question.last)[5], wk_survey_choices_attributes: questionChoiceArr}
        end

        unless params[:delete_question_ids].blank?
          delete_question_ids = params[:delete_question_ids].split(",")
          delete_question_ids.each do |deleteQuestionID|
            surveyQuestions << { id: deleteQuestionID, _destroy: "1"}
          end
        end

        survey.wk_survey_questions_attributes = surveyQuestions
      end
    else
      survey.status = params[:survey_status]
    end

    #Validate Survey For before Save
    survey_for_id = survey.survey_for_id
    survey_for = survey.survey_for_type
    if survey_for_id.present? && survey_for.present? && !(survey_for.singularize.classify.constantize.where(id: survey_for_id).exists?)
      errMsg = l(:notice_surveyfor_unsuccessful) + "<br>"
    end

    if survey.valid? && errMsg.blank?
      survey.save
      resMsg = l(:notice_successful_update)
    else
      errMsg  = errMsg + survey.errors.full_messages.join("<br>")
      resMsg = errMsg
    end

    respond_to do |format|
      format.html {
        if errMsg.blank?
          urlHash = {:surveyForType => survey.survey_for_type, :surveyForID => survey.survey_for_id }
          urlHash = get_survey_redirect_url(urlHash, params)
          redirect_to urlHash
          flash[:notice] = resMsg
        else
          flash[:error] = errMsg
          urlHash = { :project_id => params[:project_id], :controller => "wksurvey", :action => "edit", :survey_id => params[:survey_id], :surveyForType => survey.survey_for_type, :surveyForID => params[:survey_for_id] }
          redirect_to urlHash
        end
      }
      format.api {
        if errMsg.blank?
          render :plain => resMsg, :layout => nil
        else
          @error_messages = resMsg.split("<br>")
          render :template => "common/error_messages.api", :status => :unprocessable_entity, :layout => nil
        end
      }
    end
  end

  def survey
    getSurveyForType(params)
    get_response_status(params[:survey_id], params[:response_id])
    reviewUsers = getReportUsers(User.current.id).pluck(:id)
    @isReview = @survey.is_review && ["C", "R"].include?(@response.try(:status)) && reviewUsers.include?(@response.try(:user_id))
    @isReviewed = @response.try(:status) == "R"

		respond_to do |format|
			format.html {
				render layout: action_name != "print_survey"
			}
			format.api{
      }
		end
  end

  def survey_response
    sort_init "id", "asc"

    sort_update "Response_By" => "CONCAT(U.firstname, U.lastname)",
                "Response_status" => "ST.status",
                "Response_date" => "status_date"

    getSurveyForType(params)
    response_entries = WkSurveyResponse.response_list(@survey, params[:groupName], validateERPPermission("E_SUR"), convertUsersIntoString(), @surveyForType)
    response_entries = response_entries.reorder(sort_clause)

		respond_to do |format|
			format.html {
        @response_entries = formPagination(response_entries)
				render :layout => !request.xhr?
			}
			format.api{
        @entry_count = response_entries.length
        setLimitAndOffset()
        @response_entries = response_entries
      }
		end
  end

  def update_survey
    errMsg = ""
    responseStatus = Array.new
    if api_request? && params["wksurvey"].present?
      params[:survey_response_id] = params["wksurvey"]["id"]
      params[:survey_id] = params["wksurvey"]["survey_id"]
    end
    get_response_status(params[:survey_id], params[:survey_response_id])
    if @response.blank? || @response.status == "O" || to_boolean(params[:isReview])
      if api_request? && params["wksurvey"].present?
        params.permit!
        resParams = (params["wksurvey"]).to_h
        {answers: "wk_survey_answers", reviews: "wk_survey_reviews"}.each{|key, attr| resParams[attr + "_attributes"] = resParams[key] || []; resParams.delete(key)}
        survey_response = @response.blank? ? WkSurveyResponse.new : WkSurveyResponse.find(@response.id)
        survey_response.assign_attributes(resParams)
        survey_response.ip_address = request.remote_ip
        del_answers = WkSurveyAnswer.where(id: params["deletedAnswers"]) if params["deletedAnswers"].present?
      else
        surveyAnswers = Array.new
        surveyReviews = Array.new
        if to_boolean(params[:isReview])
          survey_response = WkSurveyResponse.find(params[:survey_response_id])
          params.each do |param|
            if ((param.first).include? "survey_review_") && !(param.last).blank?
              questionID = (param.first).split("_")[2]
              surveyReviews << {user_id: User.current.id, survey_question_id: questionID, survey_response_id: params[:survey_response_id], comment_text: param.last}
            end
          end
          del_answers = WkSurveyAnswer.where(survey_question_id: params[:reviewerOnlyQuestions].split(","), survey_response_id: params[:survey_response_id].to_s)
          del_reviews = WkSurveyReview.where(survey_response_id: params[:survey_response_id].to_s)
        else
          if @response.blank?
            survey_response = WkSurveyResponse.new
            survey_response.user_id = User.current.id
            survey_response.survey_id = params[:survey_id]
            survey_response.survey_for_id = params[:surveyForID] unless params[:surveyForID].blank?
            survey_response.survey_for_type = params[:surveyForType] unless params[:surveyForType].blank?
          else
            survey_response = WkSurveyResponse.find(@response.id)
            del_answers = WkSurveyAnswer.where(survey_response_id: @response.id.to_s)
          end
          survey_response.ip_address = request.remote_ip
        end
        params.each do |choice_nameVal|
          if ((choice_nameVal.first).include? "survey_sel_choice") && !(choice_nameVal.last).blank?
            sel_ids = (choice_nameVal.first).split("_")
            questionID = sel_ids[3]
            questionTypeName = "question_type_" + questionID
            questionType = params[questionTypeName]
            survey_choice_id = (["RB","CB"].include? questionType) ? choice_nameVal.last : nil
            choice_text = (["TB","MTB"].include? questionType) ? choice_nameVal.last : nil
            surveyAnswers << {survey_question_id: questionID, survey_choice_id: survey_choice_id, choice_text: choice_text} if to_boolean(params["isReviewerOnly_"+ questionID]) || params[:isReview] == "false"
          end
        end
        survey_response.wk_survey_answers_attributes = surveyAnswers
        survey_response.wk_survey_reviews_attributes = surveyReviews
      end

      #Response status
      if params[:commit] == "Submit"
        status = to_boolean(params[:isReview]) ? "R" : "C"
      else
        status = to_boolean(params[:isReview]) ? "C" : "O"
      end
      responseStatus << {status: status, status_date: Time.now, status_for_type: 'WkSurveyResponse'} if @response.try(:status) != status
      survey_response.wk_statuses_attributes = responseStatus

      if survey_response.valid? && (!surveyAnswers.blank? || !surveyReviews.blank? || api_request?)
        del_answers.destroy_all if !del_answers.blank?
        del_reviews.destroy_all if !del_reviews.blank?
        survey_response.save
      end
    end

    respond_to do |format|
      format.html {
        if @response.blank? || @response.status == "O" || to_boolean(params[:isReview])
          if survey_response.valid? && (!surveyAnswers.blank? || !surveyReviews.blank?)
            flash[:notice] = l(:notice_successful_update)
          else
            flash[:error] = survey_response.errors.full_messages.join("<br>")
            flash[:error] += l(:notice_unsuccessful_save) if surveyAnswers.blank?
          end
          urlHash = {:surveyForType => survey_response.survey_for_type, :surveyForID => survey_response.survey_for_id}
          urlHash = get_survey_redirect_url(urlHash, params)
          redirect_to urlHash
        else
          render_404
          return false
        end
      }
      format.api {
        if survey_response&.valid?
          render :plain => l(:notice_successful_update), :layout => nil
        elsif survey_response.present?
          resMsg = survey_response.errors.full_messages.join("<br>")
          resMsg += l(:notice_unsuccessful_save) if surveyAnswers.blank?
          @error_messages = resMsg.split("<br>")
          render :template => "common/error_messages.api", :status => :unprocessable_entity, :layout => nil
        else
          @error_messages = [l(:notice_file_not_found)]
          render :template => "common/error_messages.api", :status => 404, :layout => nil
        end
      }
    end
  end

  def update_status

    responseStatus = Array.new
    survey_response = WkSurveyResponse.find(params[:survey_response_id])
    get_response_status(params[:survey_id], params[:survey_response_id])
    if @response.blank? || (!@response.blank? && @response.status != params[:response_status])
      responseStatus << {status: params[:response_status], status_date: Time.now, status_for_type: "WkSurveyResponse"}
    end
    survey_response.wk_statuses_attributes = responseStatus

    if survey_response.valid? && !responseStatus.blank?
      survey_response.save
      flash[:notice] = l(:notice_successful_update)
    else
      flash[:error] = survey_response.errors.full_messages.join("<br>")
      flash[:error] += l(:notice_unsuccessful_save) if responseStatus.blank?
    end

    urlHash = {:controller => controller_name, :action => "index", :surveyForType => survey_response.survey_for_type}
    urlHash = get_survey_redirect_url(urlHash, params)
    redirect_to urlHash
  end

  def survey_result
    @survey_result_Entries = WkSurvey.find_by_sql("
      SELECT count(*) AS count, S.id, S.name, SQ.id AS question_id, SQ.name AS question_name
      FROM wk_surveys AS S
      INNER JOIN wk_survey_questions AS SQ ON SQ.survey_id = S.id
      INNER JOIN wk_survey_choices AS SC ON SQ.id = SC.survey_question_id
      WHERE (S.id = #{params[:survey_id]} AND SQ.question_type NOT IN ('TB', 'MTB') AND SQ.not_in_report = #{booleanFormat(false)})
      GROUP BY S.id, S.name, SQ.id, SQ.name
      ORDER BY S.id, SQ.id")

    @survey_txt_questions = WkSurvey.surveyTextQuestion(params[:survey_id])
    txt_answers= WkSurvey.getTextAnswer(params[:survey_id], params[:surveyForType])
    isAdmin = (validateERPPermission("E_SUR"))
    if @survey.recur?
      txt_answers = txt_answers.currentRespTxtAnswer if params[:groupName].blank? && isAdmin
      txt_answers = txt_answers.responsedTextAnswer(params[:groupName]) if params[:groupName].present? && isAdmin

      groupName = params[:groupName].present? ? params[:groupName] : getResponseGroup.last
      @groupClosedDate = WkSurveyResponse.getClosedDate(groupName)
      txt_answers = txt_answers.responsedTextAnswer(groupName) if !isAdmin
    end
    @survey_txt_answers = txt_answers
  end

  def graph
    data = get_Graph_data
    if data
      render :json => data
    else
      render_404
    end
  end

  def find_survey_for

    surveyForID = params[:surveyForID].to_i
    surveyFor = params[:method] == "search" ? "%" + params[:surveyForID] + "%" : nil
    data = Hash.new
    data = []
    case params[:surveyFor]
    when "Project"
      result = Project.where("id = ? OR LOWER(name) LIKE LOWER(?)", surveyForID, surveyFor)
      result.each do  |r|
          data << {id: r.id, label: "Project #" + r.id.to_s + ": " + r.name, value: r.id}
      end

    when "WkAccount"
      result = WkAccount.where("account_type = 'A' AND (id = ? OR LOWER(name) LIKE LOWER(?))", surveyForID, surveyFor)
      result.each do  |r|
          data << {id: r.id, label: "Account #" + r.id.to_s + ": " + r.name, value: r.id}
      end

    when "WkCrmContact"
      sql = "SELECT C.first_name, C.last_name, C.id FROM wk_crm_contacts AS C
          LEFT JOIN wk_leads AS L ON L.contact_id = C.id
          WHERE (L.status = 'C' OR L.contact_id IS NULL) AND C.contact_type = 'C' "
      surveyForIDSql = " AND (C.id = #{surveyForID})"
      surveyForSql = " AND (C.id = #{surveyForID} OR LOWER(C.first_name) LIKE LOWER('#{surveyFor}') OR LOWER(C.last_name) LIKE LOWER('#{surveyFor}'))" unless surveyFor.blank?
      sql += params[:method] == "search" ? surveyForSql : surveyForIDSql
      result = WkCrmContact.find_by_sql(sql)
      result.each do  |r|
          data << {id: r.id, label: "Contact #" + r.id.to_s + ": " + r.first_name + " " + r.last_name, value: r.id}
      end

    when "User"
      result = User.all
      surveyForIDSql = " (id = #{surveyForID})"
      surveyForSql = " (id = #{surveyForID} OR LOWER(firstname) LIKE LOWER('#{surveyFor}') OR LOWER(lastname) LIKE LOWER('#{surveyFor}'))" unless surveyFor.blank?
      result = result.where(params[:method] == "search" ? surveyForSql : surveyForIDSql)

      result.each do  |r|
          data << {id: r.id, label: "User #" + r.id.to_s + ": " + r.firstname + " " + r.lastname, value: r.id}
      end

    else
      call_hook(:find_survey_for, data: data, surveyForID: surveyForID, surveyFor: surveyFor, method: params[:method])
    end

    render :json => data
  end

  def email_user

    errMsg = ""
    survey_id = params[:survey_id]
    @survey = WkSurvey.find(survey_id)
    url = url_for(:controller => "wksurvey", :action => "survey", :survey_id => survey_id, :tab => "wksurvey")
    defaultNotes = l(:label_survey_email_notes)
    email_notes = params[:email_notes] + "\n\n" + defaultNotes + "\n" + url  + "\n\n" + l(:label_redmine_administrator)

    if params[:includeUserGroup] == "true"
      users = @survey.survey_for_type == 'User' && @survey.survey_for_id.present? ? User.where(id: @survey.survey_for_id) : WkSurvey.getMailUsers(params[:user_group])
      users.distinct.each do |user|
        WkUserNotification.userNotification(user.id, @survey, "fillSurvey") if WkNotification.notify("fillSurvey")
        errMsg += sent_emails(l(:label_survey_reminder) + "_" + @survey.name, user.language, user.mails, email_notes).to_s
      end
    end
    if params[:additional_emails].present?
        params[:additional_emails].each do |email|
            errMsg += sent_emails(l(:label_survey_reminder), nil, email, email_notes).to_s
        end
    end
    errMsg = "ok" if errMsg.blank?
    render :plain => errMsg
  end

  def destroy
    survey = WkSurvey.find(params[:survey_id].to_i)
    if survey.destroy
      flash[:notice] = l(:notice_successful_delete)
    else
      flash[:error] = survey.errors.full_messages.join("<br>")
    end
    urlHash = {:surveyForType => params[:surveyForType], :surveyForID => params[:surveyForID] }
    urlHash = get_survey_redirect_url(urlHash, params)
    redirect_to urlHash
  end

  def formPagination(entries)
    @entry_count = entries.length
    setLimitAndOffset()
    entries = entries.limit(@limit).offset(@offset)
    entries
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
      @entry_pages = Paginator.new @entry_count, per_page_option, params["page"]
      @limit = @entry_pages.per_page
      @offset = @entry_pages.offset
      @offset
    end
  end

  def check_perm_and_redirect
    get_survey(params[:survey_id], (["edit","survey_response","survey_result", "print_survey_result, update_survey"].include?(action_name)) &&
      validateERPPermission("E_SUR") || action_name == "graph") unless params[:survey_id].blank?
    survey = get_survey_with_userGroup(params[:survey_id]) unless params[:survey_id].blank? && action_name == "survey_response"
    closed_response = getResponseGroup(params[:survey_id]) unless params[:survey_id].blank?
    if "survey" == action_name
      allowSupervisor = "survey" == action_name && params[:response_id].present?
      survey = get_survey_with_userGroup(params[:survey_id], allowSupervisor).first
    end
    if !showSurvey || (!checkEditSurveyPermission && (["edit", "save_survey"].include? action_name))
      render_403
      return false
    elsif (["email_user", "update_survey"].include? action_name && @survey.try(:status) != "O") ||
      (action_name == "survey_response" && survey.blank? && !(validateERPPermission("E_SUR"))) ||
      (action_name == "survey_result" && @survey.try(:status) != "C" && !(validateERPPermission("E_SUR") || closed_response.present?)) ||
      ("survey" == action_name && !(["O", "C"].include? @survey.try(:status)))
        render_404
        return false
    end
  end

  def survey_url_validation

    is_survey_not_permitted = false
    #project tab
    if !params[:project_id].blank? && !get_project_id(params[:project_id]).blank?
      find_project_by_project_id
    elsif !params[:project_id].blank? && get_project_id(params[:project_id]).blank?
      is_survey_not_permitted = true
    end

    if !params[:id].blank? && !@project.blank?
      survey = WkSurvey.where(:id => params[:id])
      is_survey_not_permitted = true if survey.blank?
    #ERPmine tab
    elsif !params[:contact_id].blank? && params[:project_id].blank?
      contact = WkCrmContact.where(:id => params[:contact_id])
      is_survey_not_permitted = true if contact.blank?
    elsif !params[:account_id].blank? && params[:project_id].blank?
      account = WkAccount.where(:id => params[:account_id])
      is_survey_not_permitted = true if account.blank?
    elsif !params[:survey_id].blank? && params[:project_id].blank?
      survey = WkSurvey.where(:id => params[:survey_id])
      is_survey_not_permitted = true if survey.blank?
    end

    if is_survey_not_permitted
      render_404
      return false
    elsif !params[:project_id].blank? && !User.current.allowed_to?(:view_survey, @project)
      render_403
      return false
    end
  end

  def user_survey
    index
  end

  def get_survey(survey_id, isEditSurvey)
    survey = isEditSurvey ? WkSurvey.all : get_survey_with_userGroup(survey_id)
    survey = survey.where(id: survey_id) unless survey_id.blank?
    @survey = survey.first
  end

  def get_response_status(survey_id, response_id)
    getSurveyForType(params)
    @response = WkSurveyResponse.getCurrentResponse(@survey.id, response_id, @surveyForID, @surveyForType)
  end

  def close_current_response
    group_date = Time.now
    grp_name = params[:grp_name].present? ? params[:grp_name] : group_date.strftime("%Y-%m-%d %H:%M:%S").to_s
    updatedCount = WkSurveyResponse.updateRespGrp(params[:survey_id], group_date, grp_name)
    redirect_to controller: controller_name, action: "index"

    if updatedCount > 0
      flash[:notice] = l(:notice_successful_close)
    else
      flash[:error] = l(:error_no_record)
    end
  end

  def print_survey_result
    survey_result
    render :action => "print_survey_result", :layout => false
  end

  def print_survey
    survey
  end

  def check_permission
    render_404 if @survey.blank? || @survey.hide_response
  end
end
