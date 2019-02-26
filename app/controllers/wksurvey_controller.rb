class WksurveyController < ApplicationController

  menu_item :wkattendance
    
  before_action :require_login
  before_action :check_perm_and_redirect, :only => [:edit, :update]
  before_action :check_survey_perm_and_redirect, :only => [:survey]

  include WktimeHelper
  
  def index
    surveys = WkSurvey.all

    unless User.current.admin?
      surveys = surveys.where("status != 'N' AND in_active = False")
    end

    unless params[:status].blank?
      surveys = surveys.where(:status => params[:status])
    end

    unless params[:ActiveStatus].blank?
      surveys = surveys.where(:in_active => params[:ActiveStatus])
    end

    formPagination(surveys)
		
  end
  
  def survey
  
	  @survey_details = WkSurvey.find(params[:survey_id])

    if @survey_details.status == "O" && !@survey_details.in_active
      @survey_Entries = WkSurveySelChoice.joins("INNER JOIN wk_survey_choices ON wk_survey_choices.id = wk_survey_sel_choices.survey_choice_id AND wk_survey_sel_choices.user_id = " + (User.current.id).to_s).joins("RIGHT JOIN wk_survey_questions ON wk_survey_questions.id = wk_survey_choices.survey_question_id").joins("INNER JOIN wk_surveys ON wk_survey_questions.survey_id = wk_surveys.id")

      @question_Choice_Entries = @survey_Entries.joins("INNER JOIN wk_survey_choices AS SC ON wk_survey_questions.id = SC.survey_question_id").where("wk_surveys.id = ? AND wk_surveys.status = 'O' AND wk_surveys.in_active = FALSE AND wk_survey_sel_choices.survey_choice_id IS NULL", params[:survey_id]).select("SC.id, SC.name, wk_survey_questions.id AS survey_question_id").order("survey_question_id, SC.id")

      @survey_Entries = @survey_Entries.joins("INNER JOIN wk_survey_responses ON wk_surveys.id = wk_survey_responses.survey_id").where("wk_surveys.id = ? AND wk_surveys.status = 'O' AND wk_surveys.in_active = FALSE AND wk_survey_sel_choices.survey_choice_id IS NULL", params[:survey_id]).select("wk_surveys.id, wk_surveys.name, wk_survey_questions.id AS question_id, wk_survey_questions.name AS question_name, wk_survey_responses.id AS survey_response_id")
    else
      @closed_surveyed_Entries = WkSurvey.joins("INNER JOIN wk_survey_questions ON wk_survey_questions.survey_id = wk_surveys.id").where("wk_surveys.id = ? AND wk_surveys.status = 'C' AND wk_surveys.in_active = FALSE", params[:survey_id]).select("wk_surveys.id, wk_surveys.name, wk_survey_questions.id AS question_id, wk_survey_questions.name AS question_name")
    end
  end
 
  def edit

    @edit_Question_Entries = nil
    @edit_Choice_Entries = nil
    unless params[:survey_id].blank?
      @edit_Question_Entries = WkSurvey.joins("INNER JOIN wk_survey_responses ON wk_survey_responses.survey_id = wk_surveys.id")
      .joins("LEFT JOIN wk_survey_questions ON wk_survey_questions.survey_id = wk_surveys.id")
      .where(:id => params[:survey_id].to_i).select("wk_surveys.id, wk_surveys.name AS survey_name, 
        wk_surveys.status, wk_surveys.in_active, wk_survey_questions.id AS question_id, 
        wk_survey_questions.name AS question_name, wk_survey_responses.id AS response_survey_id")
    
      @edit_Choice_Entries = WkSurvey.joins("LEFT JOIN wk_survey_questions ON wk_survey_questions.survey_id = wk_surveys.id")
      .joins("LEFT JOIN wk_survey_choices ON wk_survey_questions.id = wk_survey_choices.survey_question_id")
      .where(:id => params[:survey_id].to_i)
      .select("wk_survey_questions.id AS question_id, wk_survey_choices.id AS choice_id, wk_survey_choices.name")
    end
  end
  
  def save_survey

		surveyQuestions = Array.new
    questions = Hash.new
    questionChoices = Hash.new
    survey_dependents = Hash.new

		if params[:survey_id].blank?
      survey = WkSurvey.new
      survey_dependents = {:id => nil}
		else
			survey = WkSurvey	.find(params[:survey_id].to_i)
      survey.in_active = params[:survey_inactive].blank? ? false : true
      survey_dependents = {:id => params[:responseSurveyID]}
		end
		survey.name = params[:survey_name]
    survey.status = params[:survey_status]

		params.each do |ele_nameVal|

			if ((ele_nameVal.first).include? "questionName_") && (!(ele_nameVal.last).blank?)
        question_ele = (ele_nameVal.first).split('_')
        questionID = (question_ele[1]).blank? ? nil : question_ele[1]
        qIndex = question_ele.last
        questions[qIndex] = [] if questions[qIndex].blank?
        questions[qIndex] << questionID
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
      surveyQuestions << {id: (question.last).first, name: (question.last).last, question_type: "RB", wk_survey_choices_attributes: questionChoiceArr}
    end

    unless params[:delete_question_ids].blank?
      delete_question_ids = params[:delete_question_ids].split(",")
      delete_question_ids.each do |deleteQuestionID|
        surveyQuestions << { id: deleteQuestionID, _destroy: '1'}
      end
    end

    survey.wk_survey_questions_attributes = surveyQuestions
    survey.wk_survey_responses_attributes = survey_dependents

		if survey.valid?
			survey.save
			redirect_to :controller => controller_name, :action => 'index', :tab => controller_name
			flash[:notice] = l(:notice_successful_update)
		elsif params[:survey_id].blank?
			flash[:error] = survey.errors.full_messages.join("<br>")
			redirect_to :controller => controller_name, :action => 'edit'
		else
			flash[:error] = survey.errors.full_messages.join("<br>")
			redirect_to :controller => controller_name, :action => 'edit', :survey_id => params[:survey_id]
		end
  end
  
  def update_survey
  
		errMsg = ""
		params.each do |choice_nameVal|
			if ((choice_nameVal.first).include? "survey_sel_choice") && !(choice_nameVal.last).blank?
				sel_ids = (choice_nameVal.first).split("_")
				wk_Sel_choice = WkSurveySelChoice.new(user_id: User.current.id, survey_choice_id: choice_nameVal.last, survey_response_id: sel_ids.last, ip_address: request.remote_ip)
				if wk_Sel_choice.valid?
					wk_Sel_choice.save
				else
					break
					errMsg = wk_Sel_choice.errors.full_messages.join("<br>")
				end
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

		surveyed_employees_per_choice = WkSurvey.
			joins("INNER JOIN wk_survey_questions ON wk_surveys.id = wk_survey_questions.survey_id").joins("
			INNER JOIN wk_survey_choices ON wk_survey_choices.survey_question_id = wk_survey_questions.id").joins("
			LEFT JOIN wk_survey_sel_choices ON wk_survey_sel_choices.survey_choice_id = wk_survey_choices.id").where("wk_surveys.status = 'C' AND wk_surveys.in_active IS FALSE AND wk_survey_questions.id = ?", question_id).select("COUNT(wk_survey_sel_choices.user_id) as emp_count, wk_survey_choices.id").group("wk_surveys.id, wk_survey_choices.id").order("wk_survey_choices.id")

		question_choices = WkSurvey.
			joins("INNER JOIN wk_survey_questions ON wk_surveys.id = wk_survey_questions.survey_id").joins("INNER JOIN wk_survey_choices ON wk_survey_choices.survey_question_id = wk_survey_questions.id").where("wk_surveys.status = 'C' AND wk_surveys.in_active IS FALSE AND wk_survey_questions.id = ?", question_id).select("wk_survey_choices.name").order("wk_survey_choices.id")
		
		fields = Array.new
		question_choices.each {|choice| fields << choice.name}

		employees_per_choice = Array.new
		surveyed_employees_per_choice.each_with_index do |choice, index|
			if
				employees_per_choice[index] = choice.emp_count
			end
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
end