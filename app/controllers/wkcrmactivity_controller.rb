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
			#if params[:controller_from] != controller.controller_name#'wksupplieraccount' || params[:controller_from] == 'wksuppliercontact'
			if params[:controller_from] == 'wksupplieraccount'
				redirect_to :controller => params[:controller_from],:action => params[:action_from] , :account_id => crmActivity.parent_id
			elsif params[:controller_from] == 'wksuppliercontact'
				redirect_to :controller => params[:controller_from],:action => params[:action_from] , :contact_id => crmActivity.parent_id
			else
				redirect_to :controller => 'wkcrmactivity',:action => 'index' , :tab => 'wkcrmactivity'
			end
			$tempActivity = nil			
			flash[:notice] = l(:notice_successful_update)
		else
			flash[:error] = errorMsg #wkaccount.errors.full_messages.join("<br>")
			redirect_to :controller => 'wkcrmactivity',:action => 'edit', :isError => true
		end	
    end
  
    def destroy
		parentId = WkCrmActivity.find(params[:activity_id].to_i).parent_id
		trans = WkCrmActivity.find(params[:activity_id].to_i).destroy
		flash[:notice] = l(:notice_successful_delete)
		if params[:controller_from] == 'wksupplieraccount'
			redirect_to :controller => params[:controller_from],:action => params[:action_from] , :account_id => parentId
		elsif params[:controller_from] == 'wksuppliercontact'
			redirect_to :controller => params[:controller_from],:action => params[:action_from] , :contact_id => parentId
		else
			redirect_back_or_default :action => 'index', :tab => params[:tab]
		end
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
