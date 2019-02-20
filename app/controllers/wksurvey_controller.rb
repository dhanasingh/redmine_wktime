class WksurveyController < ApplicationController

  menu_item :wkattendance
    
  before_action :require_login
  before_action :check_perm_and_redirect, :only => [:edit, :update]
  before_action :check_survey_perm_and_redirect, :only => [:survey]

  include WktimeHelper
  
  def index
    @all_surveys = nil
		@all_surveys = WkSurvey.all

		unless params[:status].blank?
			@all_surveys = @all_surveys.where(:status => params[:status])
		end

		unless params[:ActiveStatus].blank?
			@all_surveys = @all_surveys.where(:in_active => params[:ActiveStatus])
		end

		formPagination(@all_surveys)
  end
  
  def survey
  
	@survey_Entries = WkSurveySelChoice.joins("INNER JOIN wk_survey_choices ON wk_survey_choices.id = wk_survey_sel_choices.survey_choice_id AND wk_survey_sel_choices.user_id = " + (User.current.id).to_s).joins("RIGHT JOIN wk_survey_questions ON wk_survey_questions.id = wk_survey_choices.survey_question_id").joins("INNER JOIN wk_surveys ON wk_survey_questions.survey_id = wk_surveys.id")

	@survey_Choice_Entries = @survey_Entries.joins("INNER JOIN wk_survey_choices AS SC ON wk_survey_questions.id = SC.survey_question_id").where("wk_surveys.status = 'O' AND wk_surveys.in_active = FALSE AND wk_survey_sel_choices.survey_choice_id IS NULL").select("SC.id, SC.name, wk_surveys.id AS survey_id").order("survey_id, SC.id")
	
	@survey_Entries = @survey_Entries.where("wk_surveys.status = 'O' AND wk_surveys.in_active = FALSE AND wk_survey_sel_choices.survey_choice_id IS NULL").select("wk_surveys.id, wk_surveys.name")
    
    @closed_surveyed_Entries = WkSurvey.joins("INNER JOIN wk_survey_questions ON wk_survey_questions.survey_id = wk_surveys.id").where("wk_surveys.status = 'C' AND wk_surveys.in_active = FALSE").select("wk_surveys.id, wk_surveys.name")

  end
 
  def edit
	@edit_Survey_Entry = nil		
		unless params[:survey_id].blank?
			@edit_Survey_Entry = WkSurvey.joins("LEFT JOIN wk_survey_questions ON wk_survey_questions.survey_id = wk_surveys.id").joins("LEFT JOIN wk_survey_choices ON wk_survey_questions.id = wk_survey_choices.survey_question_id").where(:id => params[:survey_id].to_i).select("wk_surveys.id, wk_surveys.name AS survey_name, wk_surveys.status, wk_surveys.in_active, wk_survey_choices.id AS survey_choice_id, wk_survey_choices.name, wk_survey_questions.id AS survey_question_id")
		end
  end
  
  def updateSurvey

	if params[:survey_id].blank?
		wksurvey = WkSurvey.new
	else
		wksurvey = WkSurvey.find(params[:survey_id].to_i)
		wksurvey.status = params[:survey_status]
		wksurvey.in_active = params[:survey_inactive].blank? ? false : true
	end
	wksurvey.name = params[:survey_name]
	surveyQuestions = Array.new
	surveyChoices = Array.new

	params.each do |nameVal|
		if  (((nameVal.first).slice(0,12)).eql? "surveyChoice") && (!(nameVal.last).blank?)
			surveyChoiceid = nil
			nameids = (nameVal.first).split("_")
			unless (nameids.last).blank? || ((nameVal.first).end_with? "_")
				surveyChoiceid = nameids.last
			end
			surveyChoices << {id: surveyChoiceid, name: nameVal.last}
		end
	end

	survey_question_id = params[:survey_question_id].blank? ? nil : params[:survey_question_id]
	surveyQuestions << {id: survey_question_id, name: params[:survey_name], question_type: "RB", wk_survey_choices_attributes: surveyChoices}
	wksurvey.wk_survey_questions_attributes = surveyQuestions

	if wksurvey.valid?
		wksurvey.save
		redirect_to :controller => controller_name, :action => 'index', :tab => controller_name
		flash[:notice] = l(:notice_successful_update)
	elsif !params[:survey_id].blank?
		flash[:error] = wksurvey.errors.full_messages.join("<br>")
		redirect_to :controller => controller_name, :action => 'edit', :survey_id => params[:survey_id]
	else
		flash[:error] = wksurvey.errors.full_messages.join("<br>")
		redirect_to :controller => controller_name, :action => 'edit'
	end
  end
  
  def update_selected_survey
	user_id = User.current.id
	ip_addr = request.remote_ip
	errMsg = ""

	params.each do |nameVal|
		if (((nameVal.first).slice(0,17)).eql? "survey_sel_choice") && (!(nameVal.last).blank?)
			wk_Sel_choice = WkSurveySelChoice.new(user_id: user_id, survey_choice_id: nameVal.last, ip_address: ip_addr)
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
    data = nil
	survey_id = params[:survey_id]
    case params[:graph]
    when "choices_selected_by_user"
      data = graph_choices_selected_by_user survey_id
    end
    if data
      render :json => data
    else
      render_404
    end
  end
  
  def graph_choices_selected_by_user survey_id
    surveyed_employees = WkSurvey.
		joins("INNER JOIN wk_survey_questions ON wk_surveys.id = wk_survey_questions.survey_id").joins("
		INNER JOIN wk_survey_choices ON wk_survey_choices.survey_question_id = wk_survey_questions.id").joins("
		LEFT JOIN wk_survey_sel_choices ON wk_survey_sel_choices.survey_choice_id = wk_survey_choices.id").where("wk_surveys.status = 'C' AND wk_surveys.in_active IS FALSE AND wk_surveys.id = ?",survey_id).select("COUNT(wk_survey_sel_choices.user_id) as emp_count, wk_survey_choices.id").group("wk_surveys.id, wk_survey_choices.id").order("wk_survey_choices.id")
	
	surveyed_employees_per_choices = WkSurvey.
		joins("INNER JOIN wk_survey_questions ON wk_surveys.id = wk_survey_questions.survey_id").joins("INNER JOIN wk_survey_choices ON wk_survey_choices.survey_question_id = wk_survey_questions.id").where("wk_surveys.status = 'C' AND wk_surveys.in_active IS FALSE AND wk_surveys.id = ?",survey_id).select("wk_survey_choices.name").order("wk_survey_choices.id")
		
    fields = Array.new
    surveyed_employees_per_choices.each {|choice| fields << choice.name}
	
	employees_per_choices = Array.new
    surveyed_employees.each_with_index do |choice, index|
		if
			employees_per_choices[index] = choice.emp_count
		end
    end
	
	data = {
	:labels => fields.reverse,
	:choices => employees_per_choices.reverse,
	}
	
  end
end

