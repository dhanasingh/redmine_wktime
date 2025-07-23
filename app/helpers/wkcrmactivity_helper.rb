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
