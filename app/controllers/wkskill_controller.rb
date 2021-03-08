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
  menu_item :wkattendance
  include WkpayrollHelper
  include WktimeHelper

  before_action :check_module_permission, :only => [:index, :edit, :save, :delete]
  
  def index
    sort_init 'updated_at', 'desc'
    sort_update 'user_name' => "CONCAT(users.firstname, users.lastname)",
                'skill_set' => "wk_crm_enumerations.name",
                'rating' => "rating",
                'last_used' => "last_used",
                'experience' => "experience"
    set_filter_session
    getUsersAndGroups
    skillEntries = WkSkill.get_all
    skillEntries = skillEntries.skillUser if !validateERPPermission("A_SKILL")
    skillSet =  session[controller_name].try(:[], :skill_set)
    skillEntries = skillEntries.skillSet(skillSet) if skillSet.present? && skillSet.to_i != 0
    skillEntries = skillEntries.userGroup(session[controller_name][:group_id]) if session[controller_name].try(:[], :group_id).present? && session[controller_name].try(:[], :group_id) != "0"
    skillEntries = skillEntries.groupUser(session[controller_name][:user_id]) if session[controller_name].try(:[], :user_id).present? && session[controller_name].try(:[], :user_id) != "0"
    skillEntries = skillEntries.reorder(sort_clause)
    @skill_count = skillEntries.length
    @skill_pages = Paginator.new @skill_count, per_page_option, params['page']
    @skillEntries = skillEntries.order("id DESC").limit(@skill_pages.per_page).offset(@skill_pages.offset).to_a
  end

  def edit
    @skills = WkSkill.new
    getUsersAndGroups
    if params[:id].present?
      @skills = WkSkill.where("id =?", params[:id]).first
    end
  end

  def save
    skill = params[:wk_skill][:id].present? ? WkSkill.find(params[:wk_skill][:id]) :  WkSkill.new
    skill.assign_attributes(skill_params(params[:wk_skill]))
    if skill.save
      flash[:notice] = l(:notice_successful_update)
      redirect_to action: "index", tab: "wkskill"
    else
      flash[:error] = skill.errors.full_messages.join("<br>")
      redirect_to action: "edit", tab: "wkskill"
    end
  end
  
  def skill_params(sParams)
    sParams[:user_id] = validateERPPermission("A_SKILL") ? sParams[:user_id] : User.current.id
    sParams.permit(:id, :user_id, :skill_set_id, :rating, :last_used, :experience)
  end
  
  def delete
    WkSkill.find(params[:id].to_i).destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_back_or_default :action => 'index', :tab => params[:tab]
  end
	
	def set_filter_session
    if params[:searchlist] == controller_name || api_request?
      session[controller_name] = Hash.new if session[controller_name].nil?
      filters = [:group_id, :user_id, :skill_set, :rating, :experience, :last_used]
      filters.each do |param|
        if params[param].blank? && session[controller_name].try(:[], param).present?
          session[controller_name].delete(param)
        elsif params[param].present?
          session[controller_name][param] = params[param]
        end
      end
    end
  end

	def check_module_permission		
		unless showSkill
			render_403
			return false
		end
	end
end
