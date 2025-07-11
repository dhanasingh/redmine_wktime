# ERPmine - ERP for service industry
# Copyright (C) 2011-2021 Adhi software pvt ltd
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

  menu_item :wklead
  include WktimeHelper
  include WkdocumentHelper
  helper :wkcrmactivity
  accept_api_auth :index, :edit, :update
  before_action :change_menu_item, :only => :edit

	def index
		sort_init 'updated_at', 'desc'

		sort_update 'activity_type' => "#{WkCrmActivity.table_name}.activity_type",
					'subject_name' => "#{WkCrmActivity.table_name}.name",
					'status' => "#{WkCrmActivity.table_name}.status",
					'parent_type' => "#{WkCrmActivity.table_name}.parent_type",
					'start_date' => "#{WkCrmActivity.table_name}.start_date",
					'end_date' => "#{WkCrmActivity.table_name}.end_date",
					'assigned_user_id' => "CONCAT(U.firstname, U.lastname)",
					'updated_at' => "#{WkCrmActivity.table_name}.updated_at"

		set_filter_session
		retrieve_date_range
		load_calendar(@to) if params[:show_calendar].present?

		crmactivity = WkCrmActivity.joins("LEFT JOIN users AS U ON wk_crm_activities.assigned_user_id = U.id #{get_comp_condition('U')}")
		.where.not(activity_type: "I")

		actType = session[controller_name].try(:[], :activity_type)
		relatedTo = session[controller_name].try(:[], :related_to)
		status = session[controller_name].try(:[], :status)
		assignee = session[controller_name].try(:[], :assignee)
		if !@from.blank? && !@to.blank?
			crmactivity = crmactivity.where(:start_date => getFromDateTime(@from) .. getToDateTime(@to))
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

		crmactivity = crmactivity.where(status: status) if status.present?
		crmactivity = crmactivity.where(assigned_user_id: assignee) if assignee.present?

		crmactivity = crmactivity.reorder(sort_clause)
		respond_to do |format|
			format.html do
				formPagination(crmactivity)
				render :layout => !request.xhr?
			end
			format.api do
				@activity = crmactivity
			end
			format.csv do
				headers = { act_type: l(:label_activity_type), subject: l(:field_subject), status: l(:field_status), related: l(:label_relates_to), start_date: l(:label_start_date_time), end_date: l(:label_end_date_time), assignee: l(:field_assigned_to), updated: l(:field_updated_on) }
				data = crmactivity.map do |e|
					status = activityStatusHash[e.status]
					{ act_type: acttypeHash[e.activity_type], subject: e.name, status: status, related: relatedHash[e.parent_type], start_date: e&.start_date&.localtime&.strftime("%Y-%m-%d %H:%M:%S"), end_date: e&.end_date&.localtime&.strftime("%Y-%m-%d %H:%M:%S"), assignee: (e&.assigned_user&.name || ''), updated: e&.updated_at&.localtime&.strftime("%Y-%m-%d %H:%M:%S")}
				end
				respond_to do |format|
					format.csv {
						send_data(csv_export({headers: headers, data: data}), type: 'text/csv; header=present', filename: 'activities.csv')
					}
				end
			end
		end
	end

  def edit
    @activityEntry = nil
    unless params[:activity_id].blank?
      @activityEntry = WkCrmActivity.where(:id => params[:activity_id].to_i)
    end
    isError = params[:isError].blank? ? false : to_boolean(params[:isError])
    if !$tempActivity.blank?  && isError
      @activityEntry = $tempActivity
      respond_to do |format|
        format.html {
          render :layout => !request.xhr?
        }
        format.api
      end
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
    crmActivity.status = params[:activity_status]
    crmActivity.description = params[:activity_description]
    crmActivity.start_date = Time.parse("#{params[:activity_start_date].to_s} #{ params[:start_hour].to_s}:#{params[:start_min]}:00 ").localtime.to_s
    crmActivity.end_date = Time.parse("#{params[:activity_end_date].to_s} #{ params[:end_hour].to_s}:#{params[:end_min]}:00 ").localtime.to_s if !["C", "I"].include?(params[:activity_type])
    crmActivity.rating = params[:rating] || nil

    crmActivity.activity_type = params[:activity_type]
    crmActivity.direction = params[:activity_direction] if params[:activity_type] == 'C'
    durhr = params[:activity_duration].blank? ? "00" : params[:activity_duration]
    durmin = params[:activity_duration_min] == 0 ? "00" : params[:activity_duration_min]
    duration = "#{durhr}:#{durmin}:00".split(':').map { |a| a.to_i }.inject(0) { |a, b| a * 60 + b}
    crmActivity.duration = duration
    crmActivity.location = params[:location]  if params[:activity_type] == 'M'
    crmActivity.assigned_user_id = (params[:activity_type] != "I" || validateERPPermission("A_REFERRAL")) ? params[:assigned_user_id] : User.current.id
    crmActivity.parent_id = params[:related_parent]
    crmActivity.parent_type = params[:related_to].to_s
    crmActivity.interview_type_id = params[:interview_type] || nil
    if isChecked('crm_save_geo_location')
      crmActivity.latitude = params[:latitude]
      crmActivity.longitude = params[:longitude]
    end
    unless crmActivity.valid?
    @tempCrmActivity << crmActivity
      $tempActivity = @tempCrmActivity
      errorMsg = crmActivity.errors.full_messages.join("<br>")
    else
      crmActivity.save()
      #for attachment save
      errorMsg = save_attachments(crmActivity.id) if params[:attachments].present?
      $tempActivity = nil
    end

    respond_to do |format|
      format.html {
        if errorMsg.blank?
          if params[:controller_from] == 'wksupplieraccount'
            redirect_to :controller => params[:controller_from],:action => params[:action_from] , :account_id => crmActivity.parent_id, id: crmActivity.parent_id
          elsif params[:controller_from] == 'wksuppliercontact'
            redirect_to :controller => params[:controller_from],:action => params[:action_from] , :contact_id => crmActivity.parent_id, id: crmActivity.parent_id
          elsif params[:controller_from] == 'wkreferrals'
            redirect_back_or_default :controller => params[:controller_from], :action => 'edit', lead_id: crmActivity.parent_id, id: crmActivity.parent_id
          else
            redirect_to :controller => 'wkcrmactivity',:action => 'index' , :tab => 'wkcrmactivity'
          end
          $tempActivity = nil
          flash[:notice] = l(:notice_successful_update)
        else
          flash[:error] = errorMsg
          redirect_to :controller => 'wkcrmactivity',:action => 'edit', :isError => true
        end
      }
      format.api{
        if errorMsg.blank?
          render :plain => errorMsg, :layout => nil
        else
          @error_messages = errorMsg.split('\n')
          render :template => 'common/error_messages', :format => [:api], :status => :unprocessable_entity, :layout => nil
        end
      }
    end
  end

  def destroy
    parentId = WkCrmActivity.find(params[:activity_id].to_i).parent_id
    WkCrmActivity.find(params[:activity_id].to_i).destroy
    flash[:notice] = l(:notice_successful_delete)
    delete_documents(params[:activity_id])
    if params[:controller_from] == 'wksupplieraccount'
      redirect_to :controller => params[:controller_from],:action => params[:action_from] , :account_id => parentId
    elsif params[:controller_from] == 'wksuppliercontact'
      redirect_to :controller => params[:controller_from],:action => params[:action_from] , :contact_id => parentId
    elsif params[:controller_from] == 'wkreferrals'
      redirect_back_or_default :controller => params[:controller_from], :action => 'edit', lead_id: parentId
    else
      redirect_back_or_default :action => 'index', :tab => params[:tab]
    end
  end

  def set_filter_session
    filters = [:period_type, :period, :from, :to, :activity_type, :related_to, :show_on_map, :assignee, :status]
    super(filters, {status: ['IP', 'NS'], assignee: User.current.id, :from => @from, :to => @to})
  end

  def formPagination(entries)
    @entry_count = entries.count
    setLimitAndOffset()
    @activity = entries.limit(@limit).offset(@offset)
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

  private

  def check_perm_and_redirect
    if !check_permission && params[:controller_from] != "wkreferrals"
      render_403
      return
    end

    activity = WkCrmActivity.where(id: params[:activity_id]).first if params[:activity_id].present?
    if params[:activity_id].present? && activity.blank?
      render_404
      return
    end
  end

  def change_menu_item
    menu_items[controller_name.to_sym][:default] = params[:controller_from] == "wkreferrals" ? :wkattendance : :wklead
  end
end
