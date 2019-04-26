class WksurveyController < WkbaseController

  menu_item :wksurvey
    
	before_action :require_login
	before_action :check_proj_survey_permission
  before_action :check_perm_and_redirect, :only => [:edit, :save_survey]
  before_action :check_survey_perm_and_redirect, :only => [:survey, :update_survey, :index]

  include WktimeHelper
  include WksurveyHelper
  
	def index
		
		surveys = get_survey_with_userGroup

		unless params[:project_id].blank?
			surveys = surveys.where("(survey_for_type = 'Project' AND survey_for_id = ?) OR (survey_for_type = 'Project' AND survey_for_id IS NULL)", @project.id)
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

		if controller_name == "wksurvey" && params[:project_id].blank?
			surveys = surveys.where("survey_for_type IS NULL")
		end

    formPagination(surveys)
	end
	
	def get_survey_with_userGroup
		if checkEditSurveyPermission
			WkSurvey.all
		else
			WkSurvey.joins("LEFT JOIN groups_users ON groups_users.group_id = wk_surveys.group_id")
			.where("status IN ('O', 'C') AND (groups_users.user_id =" + (User.current.id).to_s + " OR wk_surveys.group_id IS NULL)")
		end
	end

	def survey
		
		params[:survey_id] = params[:id] unless params[:id].blank?
    @survey_details = get_survey_with_userGroup

		@survey_details = @survey_details.where("wk_surveys.id = ? AND status IN ('O', 'C')", params[:survey_id])
		@survey_details = @survey_details.first

		if @survey_details.blank?
			render_404
			return false
		else

			@isSurvey = @survey_details.status == "O" ? true : false
			if @survey_details.status == "O"

				@question_Entries = WkSurvey.find_by_sql("
					SELECT S.id, S.name, SQ.id AS question_id, SQ.name AS question_name, SQ.question_type AS question_type
					FROM wk_surveys AS S
					INNER JOIN wk_survey_questions AS SQ ON S.id = SQ.survey_id
					LEFT JOIN wk_survey_choices AS SC ON SQ.id = SC.survey_question_id
					WHERE S.status = 'O'AND S.id = #{params[:survey_id]}
					GROUP BY SQ.id, S.id, S.name, SQ.name, SQ.question_type")

				@question_Choice_Entries = WkSurvey.find_by_sql("
					SELECT SC.id, SC.name, SQ.id AS survey_question_id
					FROM wk_surveys AS S
					INNER JOIN wk_survey_questions AS SQ ON S.id = SQ.survey_id
					LEFT JOIN wk_survey_choices AS SC ON SQ.id = SC.survey_question_id 
					WHERE S.status = 'O'AND S.id = #{params[:survey_id]}")

				response_Qry = params[:response_id].blank? ? "" : " AND SR.id = #{params[:response_id]}"
				@survey_result = WkSurvey.find_by_sql("
					SELECT  S.id, S.name, SQ.id AS question_id, SQ.name AS question_name, SR.user_id, SSC.survey_choice_id, SSC.choice_text, SQ.question_type
					FROM wk_surveys AS S
					INNER JOIN wk_survey_questions AS SQ ON SQ.survey_id = S.id
					INNER JOIN wk_survey_responses AS SR ON SR.survey_id = S.id
					INNER JOIN wk_survey_sel_choices AS SSC ON SSC.survey_response_id = SR.id AND SQ.id = SSC.survey_question_id
					WHERE S.id = #{params[:survey_id]} AND S.status = 'O' AND SR.user_id = #{User.current.id}" + response_Qry)

			elsif @survey_details.status == "C"
				@closed_surveyed_Entries = WkSurvey.find_by_sql("
					SELECT S.id, S.name, SQ.id AS question_id, SQ.name AS question_name 
					FROM wk_surveys AS S
					INNER JOIN wk_survey_questions AS SQ ON wk_survey_questions.survey_id = S.id 
					INNER JOIN wk_survey_choices AS SC ON wk_survey_questions.id = wk_survey_choices.survey_question_id 
					WHERE (S.id = #{params[:survey_id]} AND S.status = 'C' AND wk_survey_questions.question_type NOT IN ('TB', 'MTB')) 
					GROUP BY S.id, S.name, wk_survey_questions.id, wk_survey_questions.name 
					ORDER BY S.id, wk_survey_questions.id")
			end

			@survey_responses = WkSurvey.find_by_sql("SELECT S.id AS survey_id, SR.id, to_char(date_trunc('second', SR.created_at), 'YYYY-MM-DD HH24:MI') AS response_date
				FROM wk_surveys AS S
				INNER JOIN wk_survey_responses AS SR ON S.id = SR.survey_id
				WHERE S.id =  #{params[:survey_id]}
				ORDER BY SR.created_at DESC")

			@isRecurEnabled =  @survey_details.recur && (@survey_details.created_at + @survey_details.recur_every.days <= Time.now) ? true : false
			@showSideNav = !@survey_responses.blank? && (@survey_responses.size >= 2 || (@survey_responses.size == 1 && @isRecurEnabled)) ? true : false
		end
	end
 
  def edit

    @edit_Survey_Entry = nil
    @edit_Question_Entries = nil
    @edit_Choice_Entries = nil
		params[:survey_id] = params[:id] unless params[:id].blank?

    unless params[:survey_id].blank?
	  @edit_Survey_Entry = WkSurvey.find(params[:survey_id].to_i)
	  
      @edit_Question_Entries = WkSurvey.joins("LEFT JOIN wk_survey_questions ON wk_survey_questions.survey_id = wk_surveys.id")
      .where(:id => params[:survey_id].to_i).select("wk_survey_questions.id AS question_id, 
				wk_survey_questions.name AS question_name, wk_survey_questions.question_type")
				.order("question_id")
		
      @edit_Choice_Entries = WkSurvey.joins("LEFT JOIN wk_survey_questions ON wk_survey_questions.survey_id = wk_surveys.id")
      .joins("LEFT JOIN wk_survey_choices ON wk_survey_questions.id = wk_survey_choices.survey_question_id")
      .where(:id => params[:survey_id].to_i)
			.select("wk_survey_questions.id AS question_id, wk_survey_choices.id AS choice_id, wk_survey_choices.name")
			.order("question_id, choice_id")
    end
  end
  
	def save_survey

		errmsg = "";
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

			if params[:survey_for_id].blank?
				survey.survey_for_id = nil
			elsif params[:IsSurveyForValid] == "true"
				survey.survey_for_id = params[:survey_for_id]
			else
				errmsg = l(:notice_surveyfor_unsuccessful) + "<br>"
			end

			params.each do |ele_nameVal|

				if ((ele_nameVal.first).include? "questionName_") && (!(ele_nameVal.last).blank?)
					question_ele = (ele_nameVal.first).split('_')
					questionID = (question_ele[1]).blank? ? nil : question_ele[1]
					qIndex = question_ele.last
					questions[qIndex] = [] if questions[qIndex].blank?
					questions[qIndex] << questionID
					questions[qIndex] << params["question_type_"+qIndex]
					questions[qIndex] << ele_nameVal.last
				end

				if ((ele_nameVal.first).include? "questionChoices_") && (!(ele_nameVal.last).blank?)
					choice_ele = (ele_nameVal.first).split("_")
					questionChoiceID = (choice_ele[3]).blank? ? nil : choice_ele[3]
					qIndex = choice_ele[2]
					questionChoices[qIndex] = [] if questionChoices[qIndex].blank?
					questionChoices[qIndex] << {id: questionChoiceID, name: ele_nameVal.last}
					deleteChoiceName = "deleteChoiceIds_"+qIndex.to_s
					unless params[deleteChoiceName].blank?
						deleteChoiceIds = params[deleteChoiceName].split(",")
						deleteChoiceIds.each do |deleteChoiceID|
							questionChoices[qIndex] << { id: deleteChoiceID, _destroy: '1'}
						end
					end
				end
			end

			questions.each do |question|
				questionChoice = question.first
				questionChoiceArr = questionChoices[questionChoice].blank? ? Array.new : questionChoices[questionChoice]
				surveyQuestions << {id: (question.last).first, name: (question.last).last, question_type: ((question.last)[1].blank? ? "RB" : (question.last)[1]), wk_survey_choices_attributes: questionChoiceArr}
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
			if params[:project_id].blank?
				redirect_to :controller => controller_name, :action => 'index', :tab => controller_name
			else
				redirect_to :project_id => params[:project_id],:controller => controller_name
			end
			flash[:notice] = l(:notice_successful_update)
		elsif params[:survey_id].blank? && errmsg.blank?
		    errmsg = errmsg + survey.errors.full_messages.join("<br>")
			flash[:error] = errmsg
			if params[:project_id].blank?
				redirect_to :controller => controller_name, :action => 'edit'
			else
				redirect_to :project_id => params[:project_id],:controller => controller_name, :action => 'edit'
			end
		else
			errmsg  = errmsg + survey.errors.full_messages.join("<br>")
			flash[:error] = errmsg
			redirect_to :controller => controller_name, :action => 'edit', :survey_id => params[:survey_id]
		end
  end
  
  def update_survey
  
		errMsg = ""
		surveyChoices = Array.new
		survey_response = WkSurveyResponse.new
		survey_response.ip_address = request.remote_ip
		survey_response.user_id = User.current.id
		survey_response.survey_id = params[:survey_id]

		params.each do |choice_nameVal|
			if ((choice_nameVal.first).include? "survey_sel_choice") && !(choice_nameVal.last).blank?
				sel_ids = (choice_nameVal.first).split("_")
				questionID = sel_ids[3]
				questionTypeName = "question_type_" + questionID
				questionType = params[questionTypeName]
				survey_choice_id = (['RB','CB'].include? questionType) ? choice_nameVal.last : nil
				choice_text = (['TB','MTB'].include? questionType) ? choice_nameVal.last : nil
				surveyChoices << {survey_question_id: questionID, survey_choice_id: survey_choice_id, choice_text: choice_text}
			end
		end

		survey_response.wk_survey_sel_choices_attributes = surveyChoices

		if survey_response.valid? && !surveyChoices.blank?
			survey_response.save
			flash[:notice] = l(:notice_successful_update)
		else
			flash[:error] = survey_response.errors.full_messages.join("<br>")
			flash[:error] += l(:notice_unsucessful_survey_response) if surveyChoices.blank?
		end

		if params[:project_id].blank?
			redirect_to :controller => controller_name, :action => 'index', :tab => controller_name
		else
			redirect_to :project_id => params[:project_id], :controller => controller_name, :action => 'index'
		end
  end
  
  def destroy
		survey = WkSurvey.find(params[:survey_id].to_i)
		if survey.destroy
			flash[:notice] = l(:notice_successful_delete)
		else
			flash[:error] = survey.errors.full_messages.join("<br>")
		end
		redirect_back_or_default :action => 'index', :tab => params[:tab]
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
		if !checkEditSurveyPermission || !showSurvey
			render_403
			return false
		end
	end
		
	def check_survey_perm_and_redirect
		if !showSurvey
			render_403
			return false
		end
  end
  
  def graph
  
		question_id = params[:question_id]

		surveyed_employees_per_choice = WkSurvey
		.joins("INNER JOIN wk_survey_questions ON wk_surveys.id = wk_survey_questions.survey_id")
		.joins("INNER JOIN wk_survey_choices ON wk_survey_questions.id = wk_survey_choices.survey_question_id")
		.joins("INNER JOIN wk_survey_sel_choices ON wk_survey_choices.id = wk_survey_sel_choices.survey_choice_id")
		.joins("INNER JOIN wk_survey_responses ON wk_survey_responses.survey_id = wk_surveys.id
			AND wk_survey_responses.id = wk_survey_sel_choices.survey_response_id")
		.where("wk_surveys.status = 'C' AND wk_survey_questions.id = ?", question_id)
		.select("COUNT(wk_survey_responses.user_id) as emp_count, wk_survey_choices.id")
		.group("wk_surveys.id, wk_survey_questions.id, wk_survey_choices.id").order("wk_survey_choices.id")

		question_choices = WkSurvey
		.joins("INNER JOIN wk_survey_questions ON wk_surveys.id = wk_survey_questions.survey_id")
		.joins("INNER JOIN wk_survey_choices ON wk_survey_choices.survey_question_id = wk_survey_questions.id")
		.where("wk_surveys.status = 'C' AND wk_survey_questions.id = ?", question_id)
		.select("wk_survey_choices.name, wk_survey_choices.id").order("wk_survey_choices.id")
		
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
  
	def survey_for_auto_complete
		
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
			when "Issue"
				result = Issue.where("id = ? OR LOWER(subject) LIKE LOWER(?)", surveyForID, surveyFor)
				result.each do  |r|
					data << {id: r.id, label: "Issue #" + r.id.to_s + ": " + r.subject, value: r.id}
				end
				
			when "Accounts"
				result = WkAccount.where("account_type = 'A' AND id = ? OR LOWER(name) LIKE LOWER(?)", surveyForID, surveyFor)
				result.each do  |r|
					data << {id: r.id, label: "Account #" + r.id.to_s + ": " + r.name, value: r.id}
				end

			when "Contact"
				sql = "SELECT C.first_name, C.last_name, C.id FROM wk_crm_contacts AS C
					LEFT JOIN wk_leads AS L ON L.contact_id = C.id
					WHERE (L.status = 'C' OR L.contact_id IS NULL)"
				surveyForIDSql = " AND (C.id = #{surveyForID})"
				surveyForSql = " AND (C.id = #{surveyForID} OR LOWER(C.first_name) LIKE LOWER('#{surveyFor}') OR LOWER(C.last_name) LIKE LOWER('#{surveyFor}'))" unless surveyFor.blank?
				sql += params[:method] == "search" ? surveyForSql : surveyForIDSql
				result = WkCrmContact.find_by_sql(sql)
				result.each do  |r|
					data << {id: r.id, label: "Contact #" + r.id.to_s + ": " + r.first_name + " " + r.last_name, value: r.id}
				end
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
		users.where(:group_id => user_group) unless user_group.blank?
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

  def email_user_permission
    survey = WkSurvey.find(params[:survey_id])
	if survey.blank? || survey.status != 'O'
		render_403
		return false
	end
  end

  def sent_emails(language, email_id, emailNotes)
	begin
	  WkMailer.email_user(language, email_id, emailNotes).deliver
	rescue Exception => e
	  errMsg = (e.message).to_s
	end
	errMsg
  end

	def check_proj_survey_permission

		unless params[:project_id].blank?
			find_project_by_project_id
		end

		unless params[:id].blank? || @project.blank?
			survey = WkSurvey.where(:id => params[:id], :survey_for_type => 'Project', :survey_for_id => @project.id)
			if survey.blank?
				render_404
				return false
			end
		end

		if !params[:survey_id].blank? && params[:project_id].blank?
			survey = WkSurvey.where(:id => params[:survey_id], :survey_for_type => nil, :survey_for_id => nil)
			if survey.blank?
				render_404
				return false
			end
		end

	end

end
