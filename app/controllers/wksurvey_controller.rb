class WksurveyController < ApplicationController

  menu_item :wkattendance
    
  before_action :require_login
  before_action :check_perm_and_redirect, :only => [:edit, :update]
  before_action :check_survey_perm_and_redirect, :only => [:survey]

  include WktimeHelper
  
	def index
		
		surveys = get_survey_with_userGroup

    unless params[:status].blank?
      surveys = surveys.where(:status => params[:status])
		end
		
    unless params[:filter_group_id].blank?
      surveys = surveys.where(:group_id => params[:filter_group_id])
    end

    formPagination(surveys)
	end
	
	def get_survey_with_userGroup
		if User.current.admin?
			WkSurvey.all
		else
			WkSurvey.joins("LEFT JOIN groups_users ON groups_users.group_id = wk_surveys.group_id")
			.where("status IN ('O', 'C') AND (groups_users.user_id =" + (User.current.id).to_s + " OR wk_surveys.group_id IS NULL)")
		end
	end

	def survey
		
    @survey_details = get_survey_with_userGroup

		@survey_details = @survey_details.where("wk_surveys.id = ? AND status IN ('O', 'C')", params[:survey_id])
		@survey_details = @survey_details.first

		if @survey_details.blank?
			render_404
		
		elsif (@survey_details).status == "O"
			survey_Entries = WkSurvey.joins("INNER JOIN wk_survey_responses ON wk_surveys.id = wk_survey_responses.survey_id")
			.joins("INNER JOIN wk_survey_questions ON wk_surveys.id = wk_survey_questions.survey_id")
			.joins("LEFT JOIN wk_survey_choices ON wk_survey_questions.id = wk_survey_choices.survey_question_id")
			.joins("LEFT JOIN wk_survey_sel_choices ON wk_survey_questions.id = wk_survey_sel_choices.survey_question_id 
				AND wk_survey_sel_choices.user_id = " + (User.current.id).to_s)
			.where("wk_surveys.status = 'O' AND wk_surveys.id = ? AND wk_survey_sel_choices.survey_question_id IS NULL", params[:survey_id])

			@question_Choice_Entries = survey_Entries.select("wk_survey_choices.id, wk_survey_choices.name, 
				wk_survey_questions.id AS survey_question_id")
			.order("wk_surveys.id, wk_survey_questions.id, wk_survey_choices.id")

			@question_Entries = survey_Entries.group("wk_survey_questions.id, wk_surveys.id, wk_surveys.name,
				wk_survey_questions.name, wk_survey_questions.question_type, wk_survey_responses.id")
			.select("wk_surveys.id, wk_surveys.name, wk_survey_questions.id AS question_id, 
				wk_survey_questions.name AS question_name, wk_survey_questions.question_type AS question_type, wk_survey_responses.id AS survey_response_id")
				.order("wk_surveys.id, wk_survey_questions.id")
		
		elsif (@survey_details).status == "C"
			@closed_surveyed_Entries = WkSurvey.joins("LEFT JOIN wk_survey_questions ON wk_survey_questions.survey_id = wk_surveys.id")
			.where("wk_surveys.id = ? AND wk_surveys.status = 'C' AND wk_survey_questions.question_type NOT IN ('TB', 'MTB')", params[:survey_id])
			.select("wk_surveys.id, wk_surveys.name, wk_survey_questions.id AS question_id, wk_survey_questions.name AS question_name")
		end
  end
 
  def edit

    @edit_Survey_Entry = nil
    @edit_Question_Entries = nil
    @edit_Choice_Entries = nil

    unless params[:survey_id].blank?
	  @edit_Survey_Entry = WkSurvey.joins("INNER JOIN wk_survey_responses ON wk_survey_responses.survey_id = wk_surveys.id").where(:id => params[:survey_id].to_i).select("wk_surveys.id, wk_surveys.status, wk_surveys.name AS survey_name, wk_surveys.group_id,  wk_survey_responses.id AS response_survey_id, wk_survey_responses.survey_for_type AS survey_for_type, wk_survey_responses.survey_for_id AS survey_for_id")
	  
      @edit_Question_Entries = WkSurvey.joins("LEFT JOIN wk_survey_questions ON wk_survey_questions.survey_id = wk_surveys.id")
      .where(:id => params[:survey_id].to_i).select("wk_survey_questions.id AS question_id, 
        wk_survey_questions.name AS question_name, wk_survey_questions.question_type")
		
      @edit_Choice_Entries = WkSurvey.joins("LEFT JOIN wk_survey_questions ON wk_survey_questions.survey_id = wk_surveys.id")
      .joins("LEFT JOIN wk_survey_choices ON wk_survey_questions.id = wk_survey_choices.survey_question_id")
      .where(:id => params[:survey_id].to_i)
      .select("wk_survey_questions.id AS question_id, wk_survey_choices.id AS choice_id, wk_survey_choices.name")
    end
  end
  
	def save_survey

		errmsg = "";
		surveyQuestions = Array.new
		questions = Hash.new
		questionChoices = Hash.new
		surveyFor = Hash.new
		survey_response_id = params[:responseSurveyID].blank? ? nil : params[:responseSurveyID]

		if params[:survey_id].blank?
			survey = WkSurvey.new
		else
			survey = WkSurvey	.find(params[:survey_id].to_i)
		end

		if survey.status.blank? || survey.status == 'N'

			survey.name = params[:survey_name]
			survey.status = params[:survey_status]
			survey.group_id = params[:group_id]

			if params[:survey_for].blank? && params[:survey_for_id].blank?
				survey_for_type = nil
				survey_for_id = nil
			elsif params[:IsSurveyForValid] == "true"
				survey_for_type =  params[:survey_for]
				survey_for_id = params[:survey_for_id]
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
			
			surveyFor = {:id => survey_response_id, :survey_for_type => survey_for_type, :survey_for_id => survey_for_id}
			survey.wk_survey_questions_attributes = surveyQuestions
			survey.wk_survey_responses_attributes = surveyFor
		else
			survey.status = params[:survey_status]
		end

		if survey.valid? && errmsg.blank?	
			survey.save
			redirect_to :controller => controller_name, :action => 'index', :tab => controller_name
			flash[:notice] = l(:notice_successful_update)
		elsif params[:survey_id].blank? && errmsg.blank?
		    errmsg = errmsg + survey.errors.full_messages.join("<br>")
			flash[:error] = errmsg
			redirect_to :controller => controller_name, :action => 'edit'
		else
			errmsg  = errmsg + survey.errors.full_messages.join("<br>")
			flash[:error] = errmsg
			redirect_to :controller => controller_name, :action => 'edit', :survey_id => params[:survey_id]
		end
  end
  
  def update_survey
  
		errMsg = ""
		survey_response_id = params[:survey_response_id]
		surveyChoices = Array.new										 
 
		params.each do |choice_nameVal|
			if ((choice_nameVal.first).include? "survey_sel_choice") && !(choice_nameVal.last).blank?
				sel_ids = (choice_nameVal.first).split("_")
				questionID = sel_ids[3]
				questionTypeName = "question_type_" + questionID
				questionType = params[questionTypeName]
				surveyChoices << {qID: questionID, qType: questionType, value: choice_nameVal.last}
			end
		end
	
		surveyChoices.each do |survey_choice|
			survey_choice_id = (['RB','CB'].include? survey_choice[:qType]) ? survey_choice[:value] : nil
			choice_text = (['TB','MTB'].include? survey_choice[:qType]) ? survey_choice[:value] : nil
			wk_Sel_choice = WkSurveySelChoice.new(user_id: User.current.id, survey_choice_id: survey_choice_id, 
				survey_question_id: survey_choice[:qID], survey_response_id: survey_response_id, ip_address: request.remote_ip, choice_text: choice_text)
		
			if wk_Sel_choice.valid?
				wk_Sel_choice.save
			else
				errMsg = wk_Sel_choice.errors.full_messages.join("<br>")
			end
		end
	
		if errMsg.blank?
			flash[:notice] = l(:notice_successful_update)
		else
			flash[:error] = errMsg
		end
		redirect_to :controller => controller_name, :action => 'index', :tab => controller_name
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
		if !User.current.admin? || !showSurvey
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
		.joins("INNER JOIN wk_survey_choices ON wk_survey_choices.survey_question_id = wk_survey_questions.id")
		.joins("LEFT JOIN wk_survey_sel_choices ON wk_survey_sel_choices.survey_choice_id = wk_survey_choices.id")
		.where("wk_surveys.status = 'C' AND wk_survey_questions.id = ?", question_id)
		.select("COUNT(wk_survey_sel_choices.user_id) as emp_count, wk_survey_choices.id")
		.group("wk_surveys.id, wk_survey_choices.id").order("wk_survey_choices.id")

		question_choices = WkSurvey
		.joins("INNER JOIN wk_survey_questions ON wk_surveys.id = wk_survey_questions.survey_id")
		.joins("INNER JOIN wk_survey_choices ON wk_survey_choices.survey_question_id = wk_survey_questions.id")
		.where("wk_surveys.status = 'C' AND wk_survey_questions.id = ?", question_id)
		.select("wk_survey_choices.name").order("wk_survey_choices.id")
		
		fields = Array.new
		question_choices.each {|choice| fields << choice.name}

		employees_per_choice = Array.new
		surveyed_employees_per_choice.each_with_index do |choice, index|
			employees_per_choice[index] = choice.emp_count
		end

		data = {
			:labels => fields.reverse,
			:emp_count_per_choices => employees_per_choice.reverse,
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

		if params[:surveyFor] == "Project"
			result = Project.where("id = ? OR LOWER(name) LIKE LOWER(?)", surveyForID, surveyFor)
			result.each do  |r|
				data << {id: r.id, label: "Project #" + r.id.to_s + ": " + r.name, value: r.id}
			end
		elsif params[:surveyFor] == "Issue"
			result = Issue.where("id = ? OR LOWER(subject) LIKE LOWER(?)", surveyForID, surveyFor)
			result.each do  |r|
				data << {id: r.id, label: "Issue #" + r.id.to_s + ": " + r.subject, value: r.id}
			end
		end

		render :json => data
  end
end