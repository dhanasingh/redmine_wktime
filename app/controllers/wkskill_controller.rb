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
    skillEntries = skillEntries.skillSet(get_filter(:skill_set)) if get_filter(:skill_set).present? && get_filter(:skill_set) != "0"
    skillEntries = skillEntries.userGroup(get_filter(:group_id)) if get_filter(:group_id).present? && get_filter(:group_id) != "0"
    skillEntries = skillEntries.groupUser(get_filter(:user_id)) if get_filter(:user_id).present? && get_filter(:user_id) != "0"
    skillEntries = skillEntries.rating(get_filter(:rating)) if get_filter(:rating).present? && get_filter(:rating) != [""]
    skillEntries = skillEntries.lastUsed(get_filter(:last_used)) if get_filter(:last_used).present? && get_filter(:last_used) != "0"
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
		filters = [:group_id, :user_id, :skill_set, :rating, :experience, :last_used]
		super(filters)
  end

	def check_module_permission		
		unless showSkill
			render_404
			return false
		end
  end

  def get_filter(key)
    return session[controller_name] && session[controller_name][key]
  end
end
