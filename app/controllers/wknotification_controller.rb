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
  end

  def update
		notifyID = WkNotification.all.pluck(:id)
    params.each do |name, value|
      if value.to_i == 1
        notifiedName = name.split('_')
        notification = WkNotification.where(modules: notifiedName.first, name: notifiedName.last).first_or_initialize(modules: notifiedName.first, name: notifiedName.last)
				if notification.save
					notifyID.delete(notification.id)
				end
      end
    end
		
		unless notifyID.blank?
			WkNotification.where(:id => notifyID).delete_all()
		end
    flash[:notice] = l(:notice_successful_update)
    redirect_to controller: 'wknotification', action: 'index' , tab: 'wknotification'
  end
end
