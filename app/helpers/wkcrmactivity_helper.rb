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
      status = (["M", "C"].include?(entry.activity_type) ? meetCallStatusHash : taskStatusHash)[entry.status]
      tip = "<span class='daytip tip'>#{link}<br><br>" +
        "<b>#{l(:field_type)}: </b>#{acttypeHash[entry.activity_type]}<br>" +
        "<b>#{l(:field_status)}: </b>#{status}<br>"+
        "<b>#{l(:label_relates_to)}: </b>#{entry.parent_type}<br>" +
        "<b>#{l(:field_name)}: </b>#{entry&.parent&.name}</span>"
      content << "<div class='dayitem tooltip'>#{link}#{tip}</div>"
    end

    content << "</div>"
    content.html_safe
  end

end