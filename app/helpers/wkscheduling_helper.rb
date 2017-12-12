# ERPmine - ERP for service industry
# Copyright (C) 2011-2018  Adhi software pvt ltd
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
module WkschedulingHelper
	include WktimeHelper
	include CalendarsHelper
	include WkattendanceHelper
	include WkcrmenumerationHelper
	
	User.class_eval do
	   has_one :wk_user, foreign_key: "user_id", class_name: "WkUser"
	end
	
	def link_to_wkcalendar_display_day(calendarObject, options={})
		s = ""
		scheduleType = "P"
		count = 1
		totalCount = 0
		seeMore = false
		dayValue = calendarObject["#{options[:day]}"]
		unless dayValue.blank?	
			totalCount = dayValue.length
			dayValue.each do | v |
				sval = v.split("-")				
				content = sval[0].capitalize 			
				content <<  link_to(h(sval[1]), url_for(:controller => controller_name, :action => 'edit', :date => options[:day], :schedule_type=> sval[3].strip, :only_path => true), :class => 'icon icon-test')
				scheduleType = sval[3].strip
				schedules = sval[2].strip
				content << " : " + content_tag(:span, (schedules == 'W' ? "Work" : "Off"), :style => "color:#{(schedules == 'W' ? "purple" : "red")};")		
				
				s =  s + content  + "<br/>".html_safe 
				if  count == 3 
					seeMore = true
					break
				end				
				count = count + 1
			end
		end		
		sm =""
		if seeMore
			sm = "<p style='float:right;'>..+#{totalCount} see more</p>"
		end
		if !s.blank?
			if scheduleType == 'S'
				s =  "<div class='preference'>" + s   + "</div>" .html_safe 
			else
				s =  "<div class='issue'>" + s +  "</div>".html_safe 
			end
			s = "<div class ='tooltip'>" + s + sm + " <span class='tip'>#{render_calendar_tooltip calendarObject, :day => options[:day], :limit => nil}</span></div>".html_safe 
		elsif options[:day].future?
			s =  "<div class='issue'>" + link_to(h("Add Preference"), url_for(:controller => controller_name, :action => 'edit', :date => options[:day], :only_path => true), :class => 'icon icon-add') + "</div>".html_safe
		end
		
		s.html_safe
	 end
	 
	 def render_calendar_tooltip(calendarObject, options={})
		content = "<div style='min-height: 100%; max-height:300px;overflow:auto;' ><table class='list time-entries'><thead><tr style=' height:30px;'><th>Name</th><th>Shift Name</th><th> Day Off </th></tr></thead><tbody>"
		scheduleType = "P"
		dayValue = calendarObject["#{options[:day]}"]
		unless dayValue.blank?	
			#ss = dayValue.first(@limit*@entry_pages.page).last(@limit)
			dayValue.each do | v |
				content << "<tr style='height:30px; font-size: 1.2em;' >".html_safe
				sval = v.split("-")				
				content << "<td>" + sval[0].capitalize + "</td>".html_safe			
				content << "<td>" + link_to(h(sval[1]), url_for(:controller => controller_name, :action => 'edit', :date => options[:day], :schedule_type=> sval[3].strip, :only_path => true), :class => 'icon icon-test') + "</td>".html_safe
				scheduleType = sval[3].strip
				schedules = sval[2].strip
				content << "<td>" + content_tag(:span, (schedules == 'W' ? "Work" : "Off"), :style => "color:#{(schedules == 'W' ? "purple" : "red")};")+ "</td></tr>".html_safe	
			end
		end
		content << "</tbody></table></div>".html_safe
		content.html_safe
	 end
	
end
