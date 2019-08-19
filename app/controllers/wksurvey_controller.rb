class WksurveyController < WkbaseController

  unloadable 
  menu_item :wksurvey
  menu_item :wkattendance, :only => :user_survey
  before_action :require_login, :survey_url_validation, :check_perm_and_redirect
  
  include WktimeHelper
  include WksurveyHelper

  def index
    sort_init 'id', 'asc'
    
    sort_update 'survey' => "#{WkSurvey.table_name}.name",
                'status' => "#{WkSurvey.table_name}.status"

    surveys = surveyList(params)
    formPagination(surveys.reorder(sort_clause))
  end

  def edit
    @survey = nil if params[:survey_id].blank?
    @edit_Question_Entries = nil
    @edit_Choice_Entries = nil
    getSurveyForType(params)
    unless params[:survey_id].blank?
      @edit_Question_Entries = WkSurvey.joins("LEFT JOIN wk_survey_questions ON wk_survey_questions.survey_id = wk_surveys.id")
      .where(:id => params[:survey_id].to_i).select("wk_survey_questions.id AS question_id, wk_survey_questions.name AS question_name, 
        wk_survey_questions.question_type, is_reviewer_only, is_mandatory").order("question_id")
        
      @edit_Choice_Entries = WkSurvey.joins("LEFT JOIN wk_survey_questions ON wk_survey_questions.survey_id = wk_surveys.id")
        .joins("LEFT JOIN wk_survey_choices ON wk_survey_questions.id = wk_survey_choices.survey_question_id")
        .where(:id => params[:survey_id].to_i)
        .select("wk_survey_questions.id AS question_id, wk_survey_choices.id AS choice_id, wk_survey_choices.name, wk_survey_choices.points")
        .order("question_id, choice_id")
    end
  end

  def save_survey
    errmsg = ""
    surveyQuestions = Array.new
    questions = Hash.new
    questionChoices = Hash.new

    if params[:survey_id].blank?
      survey = WkSurvey.new
    else
      survey = WkSurvey	.find(params[:survey_id].to_i)
    end

    if survey.status.blank? || survey.status == 'N'

      survey.name = params[:survey_name]
      survey.status = params[:survey_status]
      survey.group_id = params[:group_id]
      survey.recur = params[:recur].blank? ? false : params[:recur]
      survey.recur_every =  params[:recur].blank? ? nil : params[:recur_every]
      survey.survey_for_type = params[:survey_for].blank? ? nil : params[:survey_for]
      survey.is_review = params[:review].blank? ? false : params[:review]

      if params[:survey_for_id].blank?
        survey.survey_for_id = nil
      elsif params[:IsSurveyForValid] == "true"
        survey.survey_for_id = params[:survey_for_id]
      else
        errmsg = l(:notice_surveyfor_unsuccessful) + "<br>"
      end

      params.each do |ele_nameVal|
        #Question Array
        if ((ele_nameVal.first).include? "questionName_") && (!(ele_nameVal.last).blank?)
          question_ele = (ele_nameVal.first).split('_')
          questionID = (question_ele[1]).blank? ? nil : question_ele[1]
          qIndex = question_ele.last
          qType = params["question_type_"+qIndex]
          reviewerOnly = params["reviewerOnly_"+qIndex]
          mandatory = params["mandatory_"+qIndex]
          questions[qIndex] = [questionID, qType, ele_nameVal.last, reviewerOnly.blank? ? false : true, mandatory.blank? ? false : true]
        end

        if (((ele_nameVal.first).include? "questionChoices_") || ((ele_nameVal.first).include? "qpoints_") || ((ele_nameVal.first).include? "deleteChoiceIds_")) && (!(ele_nameVal.last).blank?)
          choice_ele = (ele_nameVal.first).split("_")
          # Deleted Choices Array
          if ((ele_nameVal.first).include? "deleteChoiceIds_")
            qIndex = choice_ele[1]
            deleteChoiceIds = ele_nameVal.last.split(",")
            questionChoices[qIndex] = [] if questionChoices[qIndex].blank?
            deleteChoiceIds.each do |deleteChoiceID|
              questionChoices[qIndex] << { id: deleteChoiceID, _destroy: '1'}
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
        surveyQuestions << {id: (question.last).first, name: (question.last)[2], question_type: ((question.last)[1].blank? ? "RB" : (question.last)[1]), is_reviewer_only: (question.last)[3], is_mandatory: (question.last)[4], wk_survey_choices_attributes: questionChoiceArr}
      end

      unless params[:delete_question_ids].blank?
        delete_question_ids = params[:delete_question_ids].split(",")
        delete_question_ids.each do |deleteQuestionID|
          surveyQuestions << { id: deleteQuestionID, _destroy: '1'}
        end
      end
      
      survey.wk_survey_questions_attributes = surveyQuestions
    else
      survey.status = params[:survey_status]
    end

    if survey.valid? && errmsg.blank?	
      survey.save
      urlHash = {:surveyForType => survey.survey_for_type, :surveyForID => survey.survey_for_id }
      urlHash = get_survey_redirect_url(urlHash, params)
      redirect_to urlHash
      flash[:notice] = l(:notice_successful_update)
    else
      errmsg  = errmsg + survey.errors.full_messages.join("<br>")
      flash[:error] = errmsg
      urlHash = { :project_id => params[:project_id], :controller => "wksurvey", :action => 'edit', :survey_id => params[:survey_id], :surveyForType => survey.survey_for_type, :surveyForID => params[:survey_for_id] }
      redirect_to urlHash
    end
  end

  def survey
    getSurveyForType(params)
    @question_Entries = WkSurvey.joins("INNER JOIN wk_survey_questions AS SQ ON wk_surveys.id = SQ.survey_id
      LEFT JOIN wk_survey_choices AS SC ON SQ.id = SC.survey_question_id")
      .where("wk_surveys.id = #{params[:survey_id]}")
      .group("SQ.id, wk_surveys.id, wk_surveys.name, SQ.name, SQ.question_type")
      .select("wk_surveys.id, wk_surveys.name, SQ.id AS question_id, SQ.name AS question_name, SQ.question_type AS question_type,
        SQ.is_mandatory, SQ.is_reviewer_only")
      .order("SQ.is_reviewer_only, SQ.id")

    @question_Choice_Entries = WkSurvey.joins("INNER JOIN wk_survey_questions AS SQ ON wk_surveys.id = SQ.survey_id
      LEFT JOIN wk_survey_choices AS SC ON SQ.id = SC.survey_question_id")
      .where("wk_surveys.id = #{params[:survey_id]}")
      .select("SC.id, SC.name, SQ.id AS survey_question_id")

    surveyFor_cnd = " AND wk_survey_responses.survey_for_type" + (@surveyForID.blank? ? " IS NULL " : " = '#{@surveyForType}' ") +
      " AND wk_survey_responses.survey_for_id" + (@surveyForID.blank? ? " IS NULL " : " = #{@surveyForID} ")

    get_response_status(params[:survey_id], params[:response_id])
    @responseStatus = @response_status.blank? ? nil : @response_status.status
    @isResetResponse = (!@response_status.blank? && @survey.recur && (@response_status.status_date + @survey.recur_every.days <= Time.now))
    @isDisable = !(@response_status.blank? || @responseStatus == "O" && (params[:response_id].blank? || (!params[:response_id].blank? && 
      params[:response_id].to_i == @response_status.id)) || @isResetResponse) || ((!@response_status.blank? || @responseStatus == "O") &&
      !([@response_status.user_id, @response_status.parent_id].include? User.current.id)) || @survey.status == "C" ||
      (User.current.id == @response_status.try(:parent_id) && @responseStatus == "O")
    responseID = params[:response_id].blank? && !@response_status.blank? ? @response_status.id : params[:response_id]

    if @isResetResponse
      @survey_response = nil
    else
      @survey_response = WkSurvey.joins("
        INNER JOIN wk_survey_questions AS SQ ON SQ.survey_id = wk_surveys.id
        INNER JOIN wk_survey_responses ON wk_survey_responses.survey_id = wk_surveys.id
        INNER JOIN wk_survey_answers AS SA ON SA.survey_response_id = wk_survey_responses.id AND SQ.id = SA.survey_question_id
        INNER JOIN wk_statuses AS ST ON ST.status_for_id = wk_survey_responses.id AND ST.status_for_type = 'WkSurveyResponse'
        LEFT JOIN wk_survey_reviews AS SR ON SR.survey_response_id = wk_survey_responses.id AND SR.survey_question_id = SQ.id")
        .where(" wk_surveys.id = #{params[:survey_id]}" + (responseID.blank? ? surveyFor_cnd + " AND wk_survey_responses.user_id = #{User.current.id} " : " AND wk_survey_responses.id = #{responseID} "))
        .group(" wk_surveys.id, wk_surveys.name, SQ.id, SQ.name, SA.survey_choice_id, SA.choice_text, 
          SQ.question_type, wk_survey_responses.id, SR.comment_text")
        .select(" wk_surveys.id, wk_surveys.name, SQ.id AS question_id, SQ.name AS question_name, wk_survey_responses.user_id, 
          SA.survey_choice_id, SA.choice_text, SQ.question_type, MAX(ST.status_date) AS status_date, wk_survey_responses.id, SR.comment_text")
    end
    reviewUsers = User.where(parent_id: User.current.id).pluck(:id)
    @reviewer = !@survey_response.blank? && (reviewUsers.include? @survey_response.first.user_id) && @survey.is_review && !@isResetResponse
    @isReview = (@reviewer || (!@response_status.blank? && "R" == @responseStatus)) && (@responseStatus != "O")
    @isReviewed = ("R" == @responseStatus)
  end

  def survey_response
    sort_init 'id', 'asc'

    sort_update 'Response_By' => "CONCAT(U.firstname, U.lastname)",
                'Response_status' => "ST.status",
                'Response_date' => "status_date"

    getSurveyForType(params)
    condStr = validateERPPermission("E_SUR") ? "" : (@survey.is_review ? 
      " AND (U.id = #{User.current.id} OR U.parent_id = #{User.current.id}) " : " AND  U.id = #{User.current.id} ")
    @surveyResponseList = WkSurveyResponse.joins("INNER JOIN wk_statuses AS ST ON ST.status_for_id = wk_survey_responses.id 
      AND ST.status_for_type = 'WkSurveyResponse'
      INNER JOIN wk_surveys AS S ON S.id = wk_survey_responses.survey_id
      INNER JOIN users AS U ON U.id = user_id AND U.type = 'User'")
      .where("survey_id = #{params[:survey_id]} " + " AND wk_survey_responses.survey_for_type " + (@surveyForType.blank? ? 
        " IS NULL " : " = '#{@surveyForType}'") + condStr)
      .group("survey_id, wk_survey_responses.id, S.name, S.survey_for_type, S.survey_for_id, ST.status, U.firstname, U.lastname, U.parent_id")
      .select("MAX(ST.status_date) AS status_date, ST.status, survey_id, wk_survey_responses.id, user_id, S.name,
      S.survey_for_type, wk_survey_responses.survey_for_id, U.firstname, U.lastname, U.parent_id").order("user_id ASC")

    @surveyResponseList = @surveyResponseList.reorder(sort_clause)
    responseEntries = Hash.new
    @surveyResponseList.each do |response|
        responseID = response.id
        if responseEntries[responseID].blank? || (!responseEntries[responseID].blank? && 
          response.status_date > responseEntries[responseID][:status_date].to_datetime)
            responseEntries.delete(responseID)
            responseEntries[responseID] = { id: response.id, survey_id: response.survey_id, status_date: response.status_date, 
              status: response.status, user_id: response.user_id, name: response.name, survey_for_type: response.survey_for_type, 
              survey_for_id: response.survey_for_id, firstname: response.firstname, lastname: response.lastname, 
              parent_id: response.parent_id }
        end
    end
    
    @response_entries = Hash.new
    @entry_count = responseEntries.length
    responseEntries = responseEntries.to_a
    setLimitAndOffset()
    page_no = (params['page'].blank? ? 1 : params['page']).to_i
    from = @offset
    to = (@limit * page_no)
    responseEntries.each_with_index do |entry, index|
        index += 1
        if index > from && index <= to
            @response_entries[entry.first] = entry.last
        end
    end
  end

  def update_survey
    errMsg = ""
    surveyAnswers = Array.new
    surveyReviews = Array.new
    responseStatus = Array.new
    get_response_status(params[:survey_id], params[:survey_response_id])

    if params[:isReview] == "true"
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
      if params[:survey_response_id].blank?
        survey_response = WkSurveyResponse.new
        survey_response.user_id = User.current.id
        survey_response.survey_id = params[:survey_id]
        survey_response.survey_for_id = params[:surveyForID] unless params[:surveyForID].blank?
        survey_response.survey_for_type = params[:surveyForType] unless params[:surveyForType].blank?
      else
        survey_response = WkSurveyResponse.find(params[:survey_response_id])
        del_answers = WkSurveyAnswer.where(survey_response_id: params[:survey_response_id].to_s)
      end
      survey_response.ip_address = request.remote_ip
    end
    params.each do |choice_nameVal|
      if ((choice_nameVal.first).include? "survey_sel_choice") && !(choice_nameVal.last).blank?
        sel_ids = (choice_nameVal.first).split("_")
        questionID = sel_ids[3]
        questionTypeName = "question_type_" + questionID
        questionType = params[questionTypeName]
        survey_choice_id = (['RB','CB'].include? questionType) ? choice_nameVal.last : nil
        choice_text = (['TB','MTB'].include? questionType) ? choice_nameVal.last : nil
        surveyAnswers << {survey_question_id: questionID, survey_choice_id: survey_choice_id, choice_text: choice_text} if params["isReviewerOnly_"+ questionID] == "true" || params[:isReview] == "false"
      end
    end

    case params[:commit]
    when "Submit"
      status = params[:isReview] == "true" ? "R" : "C"
    else
      status = params[:isReview] == "true" ? "C" : "O"
    end
    if @response_status.blank? || (!@response_status.blank? && @response_status.status != status)
      responseStatus << {status: status, status_date: Time.now, status_for_type: 'WkSurveyResponse'}
    end

    survey_response.wk_survey_answers_attributes = surveyAnswers
    survey_response.wk_survey_reviews_attributes = surveyReviews
    survey_response.wk_statuses_attributes = responseStatus
    
    if survey_response.valid? && (!surveyAnswers.blank? || !surveyReviews.blank?)
      del_answers.destroy_all if !del_answers.blank?
      del_reviews.destroy_all if !del_reviews.blank?
      survey_response.save
      flash[:notice] = l(:notice_successful_update)
    else
      flash[:error] = survey_response.errors.full_messages.join("<br>")
      flash[:error] += l(:notice_unsuccessful_save) if surveyAnswers.blank?
    end

    urlHash = {:surveyForType => survey_response.survey_for_type, :surveyForID => survey_response.survey_for_id}
    urlHash = get_survey_redirect_url(urlHash, params)
    redirect_to urlHash
  end

  def update_status
    
    responseStatus = Array.new
    survey_response = WkSurveyResponse.find(params[:survey_response_id])
    get_response_status(params[:survey_id], params[:survey_response_id])
    if @response_status.blank? || (!@response_status.blank? && @response_status.status != params[:response_status])
      responseStatus << {status: params[:response_status], status_date: Time.now, status_for_type: 'WkSurveyResponse'}
    end
    survey_response.wk_statuses_attributes = responseStatus

    if survey_response.valid? && !responseStatus.blank?
      survey_response.save
      flash[:notice] = l(:notice_successful_update)
    else
      flash[:error] = survey_response.errors.full_messages.join("<br>")
      flash[:error] += l(:notice_unsuccessful_save) if responseStatus.blank?
    end

    urlHash = {:controller => controller_name, :action => 'index', :surveyForType => survey_response.survey_for_type}
    urlHash = get_survey_redirect_url(urlHash, params)
    redirect_to urlHash
  end

  def survey_result
    @survey_result_Entries = WkSurvey.find_by_sql("
      SELECT S.id, S.name, SQ.id AS question_id, SQ.name AS question_name 
      FROM wk_surveys AS S
      INNER JOIN wk_survey_questions AS SQ ON SQ.survey_id = S.id 
      INNER JOIN wk_survey_choices AS SC ON SQ.id = SC.survey_question_id 
      WHERE (S.id = #{params[:survey_id]} AND SQ.question_type NOT IN ('TB', 'MTB')) 
      GROUP BY S.id, S.name, SQ.id, SQ.name 
      ORDER BY S.id, SQ.id")
  end

  def graph

    question_id = params[:question_id]

    if params[:surveyForID].blank?
      surveyForQry = " AND SR.survey_for_type IS NULL AND SR.survey_for_id IS NULL "
    elsif params[:surveyForType] == "User"
      surveyForQry = " AND SR.survey_for_type = '#{params[:surveyForType]}' "
    else
      surveyForQry = " AND SR.survey_for_type = '#{params[:surveyForType]}' AND SR.survey_for_id = #{params[:surveyForID]} "
    end
    surveyed_employees_per_choice = WkSurvey.find_by_sql("SELECT COUNT(SR.user_id) AS emp_count, SC.id 
      FROM wk_surveys AS S
      INNER JOIN wk_survey_questions AS SQ ON S.id = SQ.survey_id
      INNER JOIN wk_survey_choices AS SC ON SQ.id = SC.survey_question_id
      INNER JOIN wk_survey_answers AS SCC ON SC.id = SCC.survey_choice_id
      INNER JOIN wk_survey_responses AS SR ON SR.survey_id = S.id	AND SR.id = SCC.survey_response_id
      WHERE SQ.id = #{question_id} "+ surveyForQry +
      "GROUP BY S.id, SQ.id, SC.id
      ORDER BY SC.id")

    question_choices = WkSurvey.find_by_sql("SELECT SC.name, SC.id
      FROM wk_surveys AS S
      INNER JOIN wk_survey_questions AS SQ ON S.id = SQ.survey_id
      INNER JOIN wk_survey_choices AS SC ON SC.survey_question_id = SQ.id
      WHERE SQ.id = #{question_id}
      ORDER BY SC.id")

    fields = Array.new
    question_choices.each {|choice| fields << choice.name}

    sel_choices = Hash.new
    surveyed_employees_per_choice.each do |choice| 
      sel_choices[choice.id] = choice.emp_count
    end

    employees_per_choice = Array.new
    question_choices.each do |choice|
      employees_per_choice << (sel_choices[choice.id].blank? ? 0 : sel_choices[choice.id])
    end

    data = {
      :labels => fields,
      :emp_count_per_choices => employees_per_choice,
    }

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
      result = WkAccount.where("account_type = 'A' AND id = ? OR LOWER(name) LIKE LOWER(?)", surveyForID, surveyFor)
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

    errMsg = ''
    user_group = params[:user_group]
    survey_id = params[:survey_id]
    additional_emails = params[:additional_emails]
    includeUserGroup = params[:includeUserGroup]
    url = url_for(:controller => 'wksurvey', :action => 'survey', :survey_id => survey_id, :tab => 'wksurvey')
    defaultNotes = "Please click on the following link to take a survey (" + (WkSurvey.find(params[:survey_id])).name + ")"
    email_notes = defaultNotes + "\n" + url + "\n" + params[:email_notes] +"\n By Redmine Administrator"

    if includeUserGroup == "true"
        users = User.joins('INNER JOIN groups_users ON users.id = user_id')
        users = users.where("groups_users.group_id = #{user_group}") unless user_group.blank?
        users.each do |user|
        errMsg += sent_emails(user.language, user.mail, email_notes).to_s
        end
    end
    unless additional_emails.blank?
        additional_emails.each do |email|
            errMsg += sent_emails(nil, email, email_notes).to_s
        end
    end
    errMsg = 'ok' if errMsg.blank?
    render :plain => errMsg
  end

  def sent_emails(language, email_id, emailNotes)
    begin
      WkMailer.email_user(language, email_id, emailNotes).deliver
    rescue Exception => e
      errMsg = (e.message).to_s
    end
    errMsg
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
    @entry_count = entries.count
    setLimitAndOffset()
    @all_surveys = entries.order(:id).limit(@limit).offset(@offset)
    @all_surveys
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
      @offset
    end
  end

  def check_perm_and_redirect
    get_survey(params[:survey_id], (action_name == "edit")) unless params[:survey_id].blank?
    survey = get_survey_with_userGroup(params[:survey_id]) unless params[:survey_id].blank? && action_name == "survey_response"
    if !showSurvey || (!checkEditSurveyPermission && (["edit", "save_survey"].include? action_name))
      render_403
      return false
    elsif (["email_user", "update_survey"].include? action_name && @survey.try(:status) != "O") ||
      (action_name == "survey_response" && survey.blank?) || (action_name == "survey_result" && @survey.try(:status) != "C" && 
        !validateERPPermission("E_SUR")) || ("survey" == action_name && !(["O", "C"].include? @survey.try(:status)))
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
    if !response_id.blank?
      condStr = " AND wk_survey_responses.id = #{response_id.to_i}"
    else
      condStr = " AND (wk_survey_responses.user_id = #{User.current.id}) 
        AND wk_survey_responses.survey_for_type" + (@surveyForID.blank? ? 
        " IS NULL " : " = '#{@surveyForType}' ") + " AND wk_survey_responses.survey_for_id" + (@surveyForID.blank? ? 
        " IS NULL " : " = #{@surveyForID} ")
    end
    @response_status = WkSurveyResponse.joins("INNER JOIN wk_statuses AS ST ON ST.status_for_id = wk_survey_responses.id 
      AND ST.status_for_type = 'WkSurveyResponse'
      INNER JOIN users AS U ON wk_survey_responses.user_id = U.id
      INNER JOIN wk_surveys AS S ON S.id = wk_survey_responses.survey_id")
    .where(" S.id = #{survey_id}"  + condStr)
    .order("status_date DESC")
    .select("wk_survey_responses.id, ST.status, ST.status_date, U.firstname, U.lastname, U.parent_id, wk_survey_responses.user_id").first
  end
end
