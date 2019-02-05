class WkpollController < ApplicationController

  menu_item :wkattendance
    
  before_action :require_login
  before_action :check_perm_and_redirect, :only => [:edit, :update, :settings]
  before_action :check_poll_perm_and_redirect, :only => [:index]

  include WktimeHelper

  def index
  
	@poll_Entries = WkPollSelChoice.joins("INNER JOIN wk_poll_choices ON wk_poll_choices.id = wk_poll_sel_choices.poll_choice_id AND wk_poll_sel_choices.user_id = " + (User.current.id).to_s).joins("RIGHT JOIN wk_poll_questions ON wk_poll_questions.id = wk_poll_choices.poll_question_id").joins("INNER JOIN wk_polls ON wk_poll_questions.poll_id = wk_polls.id")

	@poll_Choice_Entries = @poll_Entries.joins("INNER JOIN wk_poll_choices AS PC ON wk_poll_questions.id = PC.poll_question_id").where("wk_polls.status = 'O' AND wk_polls.in_active = FALSE AND wk_poll_sel_choices.poll_choice_id IS NULL").select("PC.id, PC.name, wk_polls.id AS poll_id").order("poll_id, PC.id")
	
	@poll_Entries = @poll_Entries.where("wk_polls.status = 'O' AND wk_polls.in_active = FALSE AND wk_poll_sel_choices.poll_choice_id IS NULL").select("wk_polls.id, wk_polls.name")
    
    @closed_polled_Entries = WkPoll.joins("INNER JOIN wk_poll_questions ON wk_poll_questions.poll_id = wk_polls.id").where("wk_polls.status = 'C' AND wk_polls.in_active = FALSE").select("wk_polls.id, wk_polls.name")

  end
  
  def settings
    @all_polls = nil
		@all_polls = WkPoll.all

		unless params[:status].blank?
			@all_polls = @all_polls.where(:status => params[:status])
		end

		unless params[:ActiveStatus].blank?
			@all_polls = @all_polls.where(:in_active => params[:ActiveStatus])
		end

		formPagination(@all_polls)
  end
  
  def edit
	@edit_Poll_Entry = nil		
		unless params[:poll_id].blank?
			@edit_Poll_Entry = WkPoll.joins("LEFT JOIN wk_poll_questions ON wk_poll_questions.poll_id = wk_polls.id").joins("LEFT JOIN wk_poll_choices ON wk_poll_questions.id = wk_poll_choices.poll_question_id").where(:id => params[:poll_id].to_i).select("wk_polls.id, wk_polls.name AS poll_name, wk_polls.status, wk_polls.in_active, wk_poll_choices.id AS poll_choice_id, wk_poll_choices.name, wk_poll_questions.id AS poll_question_id")
		end
  end
  
  def updatepoll

	if params[:poll_id].blank?
		wkpoll = WkPoll.new
	else
		wkpoll = WkPoll.find(params[:poll_id].to_i)
		wkpoll.status = params[:poll_status]
		wkpoll.in_active = params[:poll_inactive].blank? ? false : true
	end
	wkpoll.name = params[:poll_name]
	pollQuestions = Array.new
	pollChoices = Array.new

	params.each do |nameVal|
		if  (((nameVal.first).slice(0,10)).eql? "pollChoice") && (!(nameVal.last).blank?)
			pollChoiceid = nil
			nameids = (nameVal.first).split("_")
			unless (nameids.last).blank? || ((nameVal.first).end_with? "_")
				pollChoiceid = nameids.last
			end
			pollChoices << {id: pollChoiceid, name: nameVal.last}
		end
	end

	poll_Question_id = params[:poll_question_id].blank? ? nil : params[:poll_question_id]
	pollQuestions << {id: poll_Question_id, name: params[:poll_name], types: "RB", wk_poll_choices_attributes: pollChoices}
	wkpoll.wk_poll_questions_attributes = pollQuestions

	if wkpoll.valid?
		wkpoll.save
		redirect_to :controller => controller_name, :action => 'settings', :tab => controller_name
		flash[:notice] = l(:notice_successful_update)
	elsif !params[:poll_id].blank?
		flash[:error] = wkpoll.errors.full_messages.join("<br>")
		redirect_to :controller => controller_name, :action => 'edit', :poll_id => params[:poll_id]
	else
		flash[:error] = wkpoll.errors.full_messages.join("<br>")
		redirect_to :controller => controller_name, :action => 'edit'
	end
  end
  
  def update_Selected_polls
	user_id = User.current.id
	ip_addr = request.remote_ip
	errMsg = ""

	params.each do |nameVal|
		if (((nameVal.first).slice(0,15)).eql? "poll_sel_choice") && (!(nameVal.last).blank?)
			wk_Sel_choice = WkPollSelChoice.new(user_id: user_id, poll_choice_id: nameVal.last, ip_address: ip_addr)
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
	poll = WkPoll.find(params[:poll_id].to_i)
	if poll.destroy
		flash[:notice] = l(:notice_successful_delete)
	else
		flash[:error] = poll.errors.full_messages.join("<br>")
	end
	redirect_back_or_default :action => 'settings', :tab => params[:tab]
  end
  
  def formPagination(entries)
	@entry_count = entries.count
	setLimitAndOffset()
	@all_polls = entries.order(:id).limit(@limit).offset(@offset)
	@all_polls
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
	if !User.current.admin? || !showPoll
		render_403
		return false
	end
  end
  
  def check_poll_perm_and_redirect
	if !showPoll
		render_403
		return false
	end
  end
  
  def graph
    data = nil
	poll_id = params[:poll_id]
    case params[:graph]
    when "choices_selected_by_user"
      data = graph_choices_selected_by_user poll_id
    end
    if data
      render :json => data
    else
      render_404
    end
  end
  
  def graph_choices_selected_by_user poll_id
    polled_employees = WkPoll.
		joins("INNER JOIN wk_poll_questions ON wk_polls.id = wk_poll_questions.poll_id").joins("
		INNER JOIN wk_poll_choices ON wk_poll_choices.poll_question_id = wk_poll_questions.id").joins("
		LEFT JOIN wk_poll_sel_choices ON wk_poll_sel_choices.poll_choice_id = wk_poll_choices.id").where("wk_polls.status = 'C' AND wk_polls.in_active IS FALSE AND wk_polls.id = ?",poll_id).select("COUNT(wk_poll_sel_choices.user_id) as emp_count, wk_poll_choices.id").group("wk_polls.id, wk_poll_choices.id").order("wk_poll_choices.id")
	
	polled_employees_per_choices = WkPoll.
		joins("INNER JOIN wk_poll_questions ON wk_polls.id = wk_poll_questions.poll_id").joins("INNER JOIN wk_poll_choices ON wk_poll_choices.poll_question_id = wk_poll_questions.id").where("wk_polls.status = 'C' AND wk_polls.in_active IS FALSE AND wk_polls.id = ?",poll_id).select("wk_poll_choices.name").order("wk_poll_choices.id")
		
    fields = Array.new
    polled_employees_per_choices.each {|choice| fields << choice.name}
	
	employees_per_choices = Array.new
    polled_employees.each_with_index do |choice, index|
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

