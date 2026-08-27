# ERPmine - ERP for service industry
# Copyright (C) 2011-  Adhi software pvt ltd
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

module WkcrmactivityHelper
  include WktimeHelper
  include WkcrmHelper

  def render_calendar_day(entries, date)
    date = date.to_date
    content = +"<div>"
    entries = entries.where("start_date <= ?", getToDateTime(date))
                      .where("end_date > ? OR end_date IS NULL", getFromDateTime(date))

    entries.each do |entry|
      next if entry.end_date.blank? && entry.start_date.localtime.to_date != date
      link = link_to(entry.name, url_for(action: 'edit', activity_id: entry.id))
      status = activityStatusHash[entry.status]
      tip = "<span class='daytip tip'>#{link}<br><br>" +
        "<b>#{l(:field_type)}: </b>#{acttypeHash[entry.activity_type]}<br>" +
        "<b>#{l(:field_status)}: </b>#{status}<br>"+
        "<b>#{l(:label_relates_to)}: </b>#{relatedHash[entry.parent_type]}<br>" +
        "<b>#{l(:field_name)}: </b>#{entry&.parent&.name}</span>"
      content << "<div class='dayitem tooltip'>#{link}#{tip}</div>"
    end

    content << "</div>"
    content.html_safe
  end

  def activity_reminder_mail
    status = ['NS', 'IP']
    from_time = getFromDateTime(Date.today)
    to_time = getToDateTime(Date.today)
    activities = WkCrmActivity.where(start_date: from_time..to_time, status: status)

    activities.each do |activity|
      next unless  activity.assigned_user&.present?

      WkMailer.send_mail(
        subject: "#{l(:label_upcoming)} - #{activity.name}",
        to: activity.assigned_user&.mail,
        body: "#{l(:label_upcoming_activity_reminder)}\n\n" +
              "#{l(:field_subject)}: #{activity.name}\n" +
              "#{l(:label_activity_type)}: #{acttypeHash[activity.activity_type]}\n" +
              "#{l(:label_relates_to)}: #{relatedHash[activity.parent_type]} - #{activity.parent&.name} \n" +
              "#{l(:label_start_date)}: #{activity.start_date.localtime.strftime('%Y-%m-%d %H:%M:%S')} & #{l(:label_end_date)}: #{activity.end_date&.localtime&.strftime('%Y-%m-%d %H:%M:%S') || ''}\n" +
              "#{l(:field_status)}: #{activityStatusHash[activity.status]}\n"
      ).deliver_later
    end
  end
end
