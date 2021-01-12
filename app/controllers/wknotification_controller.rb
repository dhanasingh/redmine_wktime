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

class WknotificationController < ApplicationController
  menu_item :wkcrmenumeration

  def index
    @notification = WkNotification.all.pluck(:name)
    @checkEmail = WkNotification.first.email
  end

  def update
    errorMsg = nil
    actionName = []
    params['notify'].each{ |key, value| actionName << key.split('_').last }
    removeName = WkNotification.where.not(name: actionName)
    removeName.destroy_all
    params['notify'].each do |name, value|
      notifiedName = name.split('_')
      notification = WkNotification.where(modules: notifiedName.first, name: notifiedName.last).first_or_initialize(modules: notifiedName.first, name: notifiedName.last)
      notification.email = params['email'] || false
      if !notification.save()
				errorMsg += notification.errors.full_messages.join('\n')
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
end
