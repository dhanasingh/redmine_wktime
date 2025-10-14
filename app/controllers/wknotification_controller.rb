# ERPmine - ERP for service industry
# Copyright (C) 2011-2020  Adhi software pvt ltd
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

class WknotificationController < WkbaseController
  menu_item :wkcrmenumeration
  accept_api_auth :index, :update_user_notification, :mark_read_notification

  def index
    @notification = WkNotification.getActiveNotification.pluck(:name)
    @checkEmail = WkNotification.getActiveNotification.first.try(:email)
    @userNotification = WkUserNotification.where('user_id = ?', User.current.id).order(id: :desc)
		respond_to do |format|
			format.html {
			  render :layout => !request.xhr?
			}
			format.api
		end
  end

  def update
    errorMsg = nil
    notifications = WkNotification.all
    if params['notify'].present?
      actionName = params['notify'].keys.map{|key| key.split('_').last}
      notifications = notifications.getUnseletedActions(actionName)
    end
    WkNotification.updateActivefalse(notifications)

    if params['notify'].present?
      params['notify'].each do |key, value|
        keys = key.split('_')
        notification = WkNotification.where(modules: keys.first, name: keys.last).first_or_initialize(modules: keys.first, name: keys.last)
        notification.email = params['email'] || false
        notification.active = true
        if !notification.save()
          errorMsg += notification.errors.full_messages.join('\n')
        end
      end
    end
    respond_to do |format|
      format.html {
        if errorMsg.nil?
          flash[:notice] = l(:notice_successful_update)
        else
          flash[:error] = errorMsg
        end
        redirect_to controller: 'wknotification', action: 'index' , tab: 'wknotification'
      }
    end
  end

  def update_user_notification
		errorMsg = nil
    usrNotification = WkUserNotification.find(params[:id])
    if usrNotification.user_id == User.current.id
      usrNotification.seen = true
      usrNotification.seen_on = Time.now
      if usrNotification.valid?
        usrNotification.save()
      else
        errorMsg = usrNotification.errors.full_messages.join("<br>")
      end
    end
		render json: errorMsg
  end

  def mark_read_notification
    errorMsg = nil
    user_id = User.current.id
    errorMsg = WkUserNotification.where(user_id: user_id, seen_on: nil).update_all(seen: true, seen_on: Time.now)
    respond_to do |format|
      format.text  { render plain: errorMsg }
      format.api  { render json: errorMsg }
    end
  end
end
