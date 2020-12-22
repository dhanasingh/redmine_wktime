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

module WkusernotificationHelper
	include ActionView::Helpers::TagHelper
  include ActionView::Helpers::UrlHelper

  include WktimeHelper

	def getNotifications
		notifications = WkUserNotification.joins("INNER JOIN wk_notifications N ON N.id = wk_user_notifications.notify_id")
			.where('user_id =? and seen = ?', User.current.id, 1)
			.select("wk_user_notifications.*, N.name")
		notifyRlt = (+"").html_safe
		notifications.each do |notification|
			text = content_tag("span", "Complete Survey: " + notification.source.name.to_s)
      notifyRlt << text
		end
		notifyRlt = content_tag("span", l(:label_no_data)) if notifyRlt.blank?
		notifyRlt
	end

  def notification_path(notification, options={})
    url_for(:controller => 'wksurvey', :action => 'survey', :survey_id => notification.source_id)
  end
end
