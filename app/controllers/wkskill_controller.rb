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

class WkskillController < WkbaseController
  before_action :check_module_permission, only: [:index, :edit, :save, :delete]
  menu_item :wkattendance
  include WkpayrollHelper
  include WktimeHelper
  include WksurveyHelper
  include WkskillHelper

  def index
    sort_init "updated_at", "desc"
    sort_update "user_name" => "CONCAT(users.firstname, users.lastname)",
                "skill_set" => "wk_crm_enumerations.name",
                "rating" => "rating",
                "last_used" => "last_used",
                "experience" => "experience",
                "interest_level" => "interest_level"
    set_filter_session
    getUsersAndGroups
    entries = WkSkill.get_entries(params[:project_id].present? ? "Project" : "User")
    entries = entries.filterByID(params[:project_id].present? ? get_project_id : User.current.id) if !validateERPPermission("A_SKILL") || params[:project_id].present?
    filters = {}
    @filters.each{|f| filters[f] = ["0", ""].include?(get_filter(f)) ? nil : get_filter(f)}
    entries = entries.skillSet(filters[:skill_set]) if filters[:skill_set]
    entries = entries.userGroup(filters[:group_id]) if filters[:group_id]
    entries = entries.groupUser(filters[:user_id]) if filters[:user_id]
    entries = entries.rating(filters[:rating])  if filters[:rating]
    entries = entries.lastUsed(filters[:last_used]) if filters[:last_used]
    entries = entries.experience(filters[:experience]) if filters[:experience]
    entries = entries.interest_level(filters[:interest_level]) if filters[:interest_level]
    entries = entries.reorder(sort_clause)

		respond_to do |format|
			format.html do
        @skill_count = entries.length
        @skill_pages = Paginator.new @skill_count, per_page_option, params["page"]
        @skillEntries = entries.limit(@skill_pages.per_page).offset(@skill_pages.offset).to_a
				render :layout => !request.xhr?
      end
			format.api
      format.csv do
        if params[:project_id].present?
          headers = {skillset: l(:label_skill_set), rating: l(:label_rating), experience: l(:label_years_of_exp), modifiedby: l(:field_status_modified_by)}
          data = entries.map{|e| {skillset: e.skill_set&.name, rating: e.rating, experience: e.experience, modifiedby: e.user&.name }}
        else
          headers = {user: l(:field_user), skillset: l(:label_skill_set), rating: l(:label_rating), interest: l(:label_interest_level),
            lastused: l(:label_last_used), experience: l(:label_years_of_exp)}
            data = entries.map{|e| {user: e.user&.name, skillset: e.skill_set&.name, rating: e.rating, interest: e.interest_level,
              lastused: e.last_used, experience: e.experience }}
        end
        send_data(csv_export(headers: headers, data: data), type: "text/csv; header=present", filename: "skills.csv")
      end
		end
  end

  def edit
    @skills = WkSkill.new(params[:project_id].present? ? {source_type: "Project", source_id: get_project_id} : {})
    getUsersAndGroups
    if params[:id].present?
      @skills = WkSkill.where("id =?", params[:id]).first
    end
  end

  def save
    skill = params[:wk_skill] && params[:wk_skill][:id].present? ? WkSkill.find(params[:wk_skill][:id]) : WkSkill.new
    skill.assign_attributes(skill_params(params[:wk_skill]))
    if skill.save
      flash[:notice] = l(:notice_successful_update)
      redirect_to action: "index", tab: "wkskill", project_id: params[:project_id]
    else
      flash[:error] = skill.errors.full_messages.join("<br>")
      redirect_to action: "edit", tab: "wkskill", project_id: params[:project_id]
    end
  end

  def skill_params(sParams)
    sParams[:user_id] = validateERPPermission("A_SKILL") ? sParams[:user_id] : User.current.id
    sParams.permit(:id, :user_id, :skill_set_id, :rating, :last_used, :experience, :source_id, :source_type, :interest_level)
  end

  def destroy
    WkSkill.find(params[:id].to_i).destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_back_or_default action: "index", tab: params[:tab], project_id: params[:project_id]
  end

	def set_filter_session
		@filters = [:group_id, :user_id, :skill_set, :rating, :experience, :last_used, :interest_level]
		super(@filters)
  end

	def check_module_permission
    if params[:project_id].present?
      menu_item = menu_items
      menu_item[controller_name.to_sym][:default] = :wkskill
      find_project_by_project_id
      view_skill = User.current.allowed_to?(:view_skill, @project)
    end
    #Only 'edit project' permission users allowed to save Project skill
    save_skill = !params[:project_id].present? || get_proj_skill_permission
		if !showSkill || params[:project_id].present? && !view_skill || !save_skill && action_name == "save"
			render_404
			return false
		end
  end

  def get_filter(key)
    return session[controller_name] && session[controller_name][key]
  end
end
