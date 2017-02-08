# ERPmine - ERP for service industry
# Copyright (C) 2011-2016  Adhi software pvt ltd
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


class WkcrmactivityController < WkcrmController
  unloadable

	include WktimeHelper

	def index
	    set_filter_session
	    retrieve_date_range
	    crmactivity = nil
		actType = session[:wkcrmactivity][:activity_type]
		relatedTo = session[:wkcrmactivity][:related_to]
	   		
		if !@from.blank? && !@to.blank?
			crmactivity = WkCrmActivity.where(:start_date => getFromDateTime(@from) .. getToDateTime(@to))
		else
			crmactivity = WkCrmActivity.all
		end
		
		if (!actType.blank?) && (relatedTo.blank?)
			crmactivity = crmactivity.where(:activity_type => actType)
		end
		
		if (actType.blank?) && (!relatedTo.blank?)
			crmactivity = crmactivity.where(:parent_type => relatedTo)
		end
		
		if (!actType.blank?) && (!relatedTo.blank?)
			crmactivity = crmactivity.where(:activity_type => actType, :parent_type => relatedTo)
		end
		
		formPagination(crmactivity)
	end
  
    def edit
		@activityEntry = nil
		unless params[:activity_id].blank?
			@activityEntry = WkCrmActivity.where(:id => params[:activity_id].to_i)
		end
		isError = params[:isError].blank? ? false : to_boolean(params[:isError])
		if !$tempActivity.blank?  && isError
			@activityEntry = $tempActivity
		end
    end
  
    def update
		errorMsg = nil
		crmActivity = nil
		@tempCrmActivity ||= Array.new
		unless params[:crm_activity_id].blank?
			crmActivity = WkCrmActivity.find(params[:crm_activity_id].to_i)
			crmActivity.updated_by_user_id = User.current.id
		else
			crmActivity = WkCrmActivity.new
			crmActivity.created_by_user_id = User.current.id
		end
		crmActivity.name = params[:activity_subject]
		crmActivity.status =  params[:activity_type] == 'C' || params[:activity_type] == 'M' ? params[:activity_status] : params[:task_status]
		crmActivity.description = params[:activity_description]
		crmActivity.start_date = Time.parse("#{params[:activity_start_date].to_s} #{ params[:start_hour].to_s}:#{params[:start_min]}:00 ").localtime.to_s
		crmActivity.end_date = Time.parse("#{params[:activity_end_date].to_s} #{ params[:end_hour].to_s}:#{params[:end_min]}:00 ").localtime.to_s if params[:activity_type] != 'C'
		
		crmActivity.activity_type = params[:activity_type]
		crmActivity.direction = params[:activity_direction] if params[:activity_type] == 'C'
		durhr = params[:activity_duration].blank? ? "00" : params[:activity_duration]
		durmin = params[:activity_duration_min] == 0 ? "00" : params[:activity_duration_min]
		duration = "#{durhr}:#{durmin}:00".split(':').map { |a| a.to_i }.inject(0) { |a, b| a * 60 + b}
		crmActivity.duration = duration 
		crmActivity.location = params[:location]  if params[:activity_type] == 'M'
		crmActivity.assigned_user_id = params[:assigned_user_id]
		crmActivity.parent_id = params[:related_parent]
		crmActivity.parent_type = params[:related_to].to_s
		unless crmActivity.valid?
		@tempCrmActivity << crmActivity
			$tempActivity = @tempCrmActivity
			errorMsg = crmActivity.errors.full_messages.join("<br>")
		else			
			crmActivity.save()
			$tempActivity = nil 
		end
		
		if errorMsg.blank?
			redirect_to :controller => 'wkcrmactivity',:action => 'index' , :tab => 'wkcrmactivity'
			$tempActivity = nil			
			flash[:notice] = l(:notice_successful_update)
		else
			flash[:error] = errorMsg #wkaccount.errors.full_messages.join("<br>")
			redirect_to :controller => 'wkcrmactivity',:action => 'edit', :isError => true
		end	
    end
  
    def destroy
		trans = WkCrmActivity.find(params[:activity_id].to_i).destroy
		flash[:notice] = l(:notice_successful_delete)
		redirect_back_or_default :action => 'index', :tab => params[:tab]
    end
	
	 def set_filter_session
        if params[:searchlist].blank? && session[:wkcrmactivity].nil?
			session[:wkcrmactivity] = {:period_type => params[:period_type],:period => params[:period],	:activity_type =>	params[:activity_type],	 :from => @from, :to => @to}
		elsif params[:searchlist] =='wkcrmactivity'
			session[:wkcrmactivity][:period_type] = params[:period_type]
			session[:wkcrmactivity][:period] = params[:period]
			session[:wkcrmactivity][:from] = params[:from]
			session[:wkcrmactivity][:to] = params[:to]
			session[:wkcrmactivity][:activity_type] = params[:activity_type]
			session[:wkcrmactivity][:related_to] = params[:related_to]
		end
		
    end
   
   # Retrieves the date range based on predefined ranges or specific from/to param dates
	def retrieve_date_range
		@free_period = false
		@from, @to = nil, nil
		period_type = session[:wkcrmactivity][:period_type]
		period = session[:wkcrmactivity][:period]
		fromdate = session[:wkcrmactivity][:from]
		todate = session[:wkcrmactivity][:to]
		
		if (period_type == '1' || (period_type.nil? && !period.nil?)) 
		    case period.to_s
			  when 'today'
				@from = @to = Date.today
			  when 'yesterday'
				@from = @to = Date.today - 1
			  when 'current_week'
				@from = getStartDay(Date.today - (Date.today.cwday - 1)%7)
				@to = @from + 6
			  when 'last_week'
				@from =getStartDay(Date.today - 7 - (Date.today.cwday - 1)%7)
				@to = @from + 6
			  when '7_days'
				@from = Date.today - 7
				@to = Date.today
			  when 'current_month'
				@from = Date.civil(Date.today.year, Date.today.month, 1)
				@to = (@from >> 1) - 1
			  when 'last_month'
				@from = Date.civil(Date.today.year, Date.today.month, 1) << 1
				@to = (@from >> 1) - 1
			  when '30_days'
				@from = Date.today - 30
				@to = Date.today
			  when 'current_year'
				@from = Date.civil(Date.today.year, 1, 1)
				@to = Date.civil(Date.today.year, 12, 31)
	        end
		elsif period_type == '2' || (period_type.nil? && (!fromdate.nil? || !todate.nil?))
		    begin; @from = fromdate.to_s.to_date unless fromdate.blank?; rescue; end
		    begin; @to = todate.to_s.to_date unless todate.blank?; rescue; end
		    @free_period = true
		else
		  # default
		  # 'current_month'		
			@from = Date.civil(Date.today.year, Date.today.month, 1)
			@to = (@from >> 1) - 1
	    end    
		
		@from, @to = @to, @from if @from && @to && @from > @to

	end
	
	def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		@activity = entries.order(updated_at: :desc).limit(@limit).offset(@offset)
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
		end	
	end


end
