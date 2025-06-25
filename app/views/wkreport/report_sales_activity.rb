# ERPmine - ERP for service industry
# Copyright (C) 2011-2021 Adhi software pvt ltd
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

module ReportSalesActivity
	include WkcrmHelper
  include WkreportHelper

	def calcReportData(userId, groupId, projId, from, to)
		from = from.to_date
		to = to.to_date
		activityList = getActivityList(from, to, groupId, userId)
		activities = {}
		totalTime = 0
		activityList.each do |activity|
			activities[activity.id] = {}
			isSupplier = false
			if activity.parent_type == 'WkAccount'
				isSupplier = true unless activity.parent.account_type == 'A'
			elsif activity.parent_type == 'WkCrmContact'
				isSupplier = true unless activity.parent.contact_type == 'C'
			end
			unless isSupplier
				completionTime = (activity.status == 'C' || activity.status == 'H') ? convertSecToDays(activity.status_update_on - activity.start_date) : nil
				totalTime = totalTime + (completionTime || 0)
				activities[activity.id]['type'] = acttypeHash[activity.activity_type]
				activities[activity.id]['name'] = activity.name
				activities[activity.id]['status'] = activityStatusHash[activity.status]
				activities[activity.id]['parent_type'] = relatedHash[activity.parent_type]
				activities[activity.id]['parent_name'] = activity.parent&.name || ''
				activities[activity.id]['start_date'] = activity.start_date.localtime.strftime("%Y-%m-%d %H:%M:%S")
				activities[activity.id]['complete_date'] = activity.status == 'C' || activity.status == 'H' ? activity.status_update_on.localtime.strftime("%Y-%m-%d %H:%M:%S") : ''
				activities[activity.id]['assigned_user'] = activity.assigned_user&.name || ''
				activities[activity.id]['duration'] = completionTime
			end
		end
		duration = activityList.length > 0 ? (totalTime/activityList.length).round(2).to_s + " " + l(:label_day_plural) : ''
		stock = {activities: activities, totDuration: duration, from: from.to_formatted_s(:long), to: to.to_formatted_s(:long)}
		stock
	end

  def getExportData(user_id, group_id, projId, from, to)
    data = {headers: {}, data: []}
    reportData = calcReportData(user_id, group_id, projId, from, to)
    data[:headers] = {activity_type: l(:label_activity_type), subject: l(:field_subject), status: l(:field_status), relates_to: l(:label_relates_to), name: l(:field_name), start_date_time: l(:label_start_date_time), complete_date: 'Completed Date', assignee: l(:field_assigned_to), duration: l(:label_duration)+' '+l(:label_day_plural)}
    reportData[:activities].each do |key, activity|
      data[:data] << activity
    end
    if reportData[:activities].length > 0
      duration =  {activity_type: '', subject: '', status: '', relates_to: '', name: '', start_date_time: '', complete_date: '', assignee: l(:label_average) + " " + l(:label_duration), duration: reportData[:totDuration]}
      data[:data] << duration
    end
    data
  end

	def pdf_export(data)
    pdf = ITCPDF.new(current_language,'L')
    pdf.add_page
    row_Height = 8
    page_width    = pdf.get_page_width
    left_margin   = pdf.get_original_margins['left']
    right_margin  = pdf.get_original_margins['right']
    table_width = page_width - right_margin - left_margin
    width = table_width/data[:headers].length

    pdf.SetFontStyle('B', 13)
    pdf.RDMMultiCell(table_width, 5, data[:location], 0, 'C')
    pdf.RDMMultiCell(table_width, 5, l(:report_sales_activity) + " " + l(:label_report), 0, 'C')
    pdf.RDMMultiCell(table_width, 5, data[:from].to_s+" "+ l(:label_date_to) +" "+data[:to].to_s, 0, 'C')

		logo =data[:logo]
		if logo.present?
			pdf.Image(logo.diskfile.to_s, page_width-50, 15, 30, 25)
		end
		pdf.ln(10)
    pdf.SetFontStyle('B', 8)
    pdf.set_fill_color(230, 230, 230)
    data[:headers].each{ |key, value| pdf.RDMCell(width, row_Height, value.to_s, 1, 0, 'C', 1) }
    pdf.ln
    pdf.set_fill_color(255, 255, 255)

    pdf.SetFontStyle('', 8)
    data[:data].each do |entry|
			entry.each{ |key, value|
				pdf.SetFontStyle('B', 8) if entry == data[:data].last
				pdf.RDMCell(width, row_Height, value.to_s, 1, 0, 'C', 1)
			}
    	pdf.ln
    end
    pdf.Output
  end
end