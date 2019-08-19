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

module WktimeHelper
  include ApplicationHelper
  include Redmine::Export::PDF
  include Redmine::Export::PDF::IssuesPdfHelper
  include Redmine::Utils::DateCalculation
  

	def options_for_period_select(value)
		options_for_select([[l(:label_all_time), 'all'],
							[l(:label_this_week), 'current_week'],
							[l(:label_last_week), 'last_week'],
							[l(:label_this_month), 'current_month'],
							[l(:label_last_month), 'last_month'],
							[l(:label_this_year), 'current_year']],
							value.blank? ? 'current_month' : value)
	end

	def options_wk_status_select(value)
		options_for_select([[l(:wk_status_empty), 'e'],
							[l(:wk_status_new), 'n'],
							[l(:wk_status_rejected), 'r'],
							[l(:wk_status_submitted), 's'],
							[l(:wk_status_approved), 'a']],
							value.blank? ? ['e','n','r','s','a'] : value)
	end
	
	def options_for_sheet_select(value)
		options_for_select([[l(:label_weekly), 'W'],
							[l(:label_issue_view), 'I']],
							value.blank? ? 'current_month' : value)
	end
	
	def statusString(status)	
		statusStr = l(:wk_status_new)
		case status
		when 'a'
			statusStr = l(:wk_status_approved)
		when 'r'
			statusStr = l(:wk_status_rejected)
		when 's'
			statusStr = l(:wk_status_submitted)
		when 'e'
			statusStr = l(:wk_status_empty)
		else
			statusStr = l(:wk_status_new)
		end
		return statusStr
	end
	
	# Indentation of Subprojects based on levels
	def options_for_wktime_project(projects, needBlankRow=false)
		projArr = Array.new
		if needBlankRow
			projArr << [ "", ""]
		end
		
		#Project.project_tree(projects) do |proj_name, level|
		if !projects.blank?
			project_tree(projects) do |proj, level|
				indent_level = (level > 0 ? ('&nbsp;' * 2 * level + '&#187; ').html_safe : '')
				sel_project = projects.select{ |p| p.id == proj.id }
				projArr << [ (indent_level + sel_project[0].name), sel_project[0].id ]
			end
		end
		projArr
	end

  # Returns a CSV string of a weekly timesheet
  def wktime_to_csv(entries, user, startday, unitLabel)
    decimal_separator = l(:general_csv_decimal_separator)
    #custom_fields = WktimeCustomField.find(:all)
	custom_fields = WktimeCustomField.all
    export = Redmine::Export::CSV.generate do |csv|
      # csv header fields
      headers = [l(:field_user),
                 l(:field_project),
                 l(:field_issue),
                 l(:field_activity)
                 ]
		if !unitLabel.blank?
			headers << l(:label_wk_currency)
		end
		unit=nil
		
		set_cf_header(headers, nil, 'wktime_enter_cf_in_row1')
		set_cf_header(headers, nil, 'wktime_enter_cf_in_row2')
		
		hoursIndex = headers.size
		startOfWeek = getStartOfWeek
		for i in 0..6
			#Use "\n" instead of '\n'
			#Martin Dube contribution: 'start of the week' configuration		
			headers << (l('date.abbr_day_names')[(i+startOfWeek)%7] + "\n" + I18n.localize(@startday+i, :format=>:short)) unless @startday.nil?
		end
		csv << headers.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, l(:general_csv_encoding) )  }
		weeklyHash = getWeeklyView(entries, unitLabel, true, nil, 7) #should send false and form unique rows
		col_values = []
		matrix_values = nil
		totals = [0.0,0.0,0.0,0.0,0.0,0.0,0.0]
		weeklyHash.each do |key, matrix|
			matrix_values, j = getColumnValues(matrix, totals, unitLabel,false,0)
			col_values = matrix_values[0]
			#add the user name to the values
			col_values.unshift(user.name)
			csv << col_values.collect {|c| Redmine::CodesetUtil.from_utf8(
								c.to_s, l(:general_csv_encoding) )  }
			if !unitLabel.blank?
				unit=matrix_values[0][4]
			end
		end
		total_values = getTotalValues(totals, hoursIndex,unit)
		#add an empty cell to cover for the user column
		#total_values.unshift("")
		csv << total_values.collect {|t| Redmine::CodesetUtil.from_utf8(
								t.to_s, l(:general_csv_encoding) )  }
    end
    export
  end
	

  # Returns a PDF string of a weekly timesheet
  def wktime_to_pdf(entries, user, startday, unitLabel)

	# Landscape A4 = 210 x 297 mm
	page_height   = Setting.plugin_redmine_wktime['wktime_page_height'].to_i
	page_width    = Setting.plugin_redmine_wktime['wktime_page_width'].to_i
	right_margin  = Setting.plugin_redmine_wktime['wktime_margin_right'].to_i
	left_margin  = Setting.plugin_redmine_wktime['wktime_margin_left'].to_i
	bottom_margin = Setting.plugin_redmine_wktime['wktime_margin_bottom'].to_i
	top_margin = Setting.plugin_redmine_wktime['wktime_margin_top'].to_i
	col_id_width  = 10
	row_height    = Setting.plugin_redmine_wktime['wktime_line_space'].to_i
	logo    = Setting.plugin_redmine_wktime['wktime_header_logo']

	if page_height == 0
		page_height = 297
	end
	if page_width == 0
		page_width  = 210
	end	
	if right_margin == 0
		right_margin = 10
	end	
	if left_margin == 0
		left_margin = 10
	end
	if bottom_margin == 0
		bottom_margin = 20
	end
	if top_margin == 0
		top_margin = 20
	end
	if row_height == 0
		row_height = 4
	end
	
	# column widths
	table_width = page_width - right_margin - left_margin
	
	columns = ["#",l(:field_project), l(:field_issue), l(:field_activity)]
	
	
	col_width = []
	orientation = "P"
	unit=nil
	# 20% for project, 60% for issue, 20% for activity
	col_width[0]=col_id_width
	col_width[1] = (table_width - (8*10))*0.2
	col_width[2] = (table_width - (8*10))*0.6
	col_width[3] = (table_width - (8*10))*0.2
	title=l(:label_wktime)
	if !unitLabel.blank?
		columns << l(:label_wk_currency)
		col_id_width  = 14
		col_width[0]=col_id_width
		col_width[1] = (table_width - (8*14))*0.20
		col_width[2] = (table_width - (8*14))*0.44
		col_width[3] = (table_width - (8*14))*0.16
		col_width[4] = (table_width - (8*14))*0.20
		title= l(:label_wkexpense)
	end	
	
	set_cf_header(columns, col_width, 'wktime_enter_cf_in_row1')
	set_cf_header(columns, col_width, 'wktime_enter_cf_in_row2')
	
	hoursIndex = columns.size
	startOfWeek = getStartOfWeek
	for i in 0..6
		#Martin Dube contribution: 'start of the week' configuration		
		columns << l('date.abbr_day_names')[(i+startOfWeek)%7] + "\n" + (startday+i).mon().to_s() + "/" + (startday+i).day().to_s()
		col_width << col_id_width
	end	
	
	#Landscape / Potrait
	if(table_width > 220)
		orientation = "L"
	else
		orientation = "P"
	end
	
	pdf = ITCPDF.new(current_language)
		
	pdf.SetTitle(title)
	pdf.alias_nb_pages
	pdf.footer_date = format_date(Date.today)
	pdf.SetAutoPageBreak(false)
	pdf.AddPage(orientation)
	
	if !logo.blank? && (File.exist? (Redmine::Plugin.public_directory + "/redmine_wktime/images/" + logo))
		pdf.Image(Redmine::Plugin.public_directory + "/redmine_wktime/images/" + logo, page_width-50, 10,40,25)
	end
	
	render_header(pdf, entries, user, startday, row_height,title)

	pdf.Ln
	render_table_header(pdf, columns, col_width, row_height, table_width)

	weeklyHash = getWeeklyView(entries, unitLabel, true, nil, 7)
	col_values = []
	matrix_values = []
	totals = [0.0,0.0,0.0,0.0,0.0,0.0,0.0]
	grand_total = 0.0
	j = 0
	base_x = pdf.GetX
	base_y = pdf.GetY
	max_height = row_height
	  
	weeklyHash.each do |key, matrix|
		matrix_values, j = getColumnValues(matrix, totals, unitLabel,true, j)
		col_values = matrix_values[0]
		base_x = pdf.GetX
		base_y = pdf.GetY
		pdf.SetY(2 * page_height)
		
		#write once to get the height
		max_height = wktime_to_pdf_write_cells(pdf, col_values, col_width, row_height)
		#reset the x and y
		pdf.SetXY(base_x, base_y)

		# make new page if it doesn't fit on the current one
		space_left = page_height - base_y - bottom_margin
		if max_height > space_left
			render_newpage(pdf,orientation,logo,page_width)
			render_table_header(pdf, columns, col_width, row_height,  table_width)
			base_x = pdf.GetX
			base_y = pdf.GetY
		end

		# write the cells on page
		wktime_to_pdf_write_cells(pdf, col_values, col_width, row_height)
		issues_to_pdf_draw_borders(pdf, base_x, base_y, base_y + max_height, 0, col_width)
		pdf.SetY(base_y + max_height);
		if !unitLabel.blank?
			unit=matrix_values[0][4]
		end
	end

	total_values = getTotalValues(totals,hoursIndex,unit)
	
	#write total
	#write an empty id
	
	max_height = wktime_to_pdf_write_cells(pdf, total_values, col_width, row_height)
	
	pdf.SetY(pdf.GetY + max_height);
	pdf.SetXY(pdf.GetX, pdf.GetY)
	
	render_signature(pdf, page_width, table_width, row_height,bottom_margin,page_height,orientation,logo)
	pdf.Output
  end
  
	# Renders MultiCells and returns the maximum height used
	def wktime_to_pdf_write_cells(pdf, col_values, col_widths,
								row_height)
		base_y = pdf.GetY
		max_height = row_height
		col_values.each_with_index do |val, i|
			col_x = pdf.GetX
			if val.nil?
                val =''
            end
			pdf.RDMMultiCell(col_widths[i], row_height, val, "T", 'L', 1)
			max_height = max_height < pdf.getStringHeight(col_widths[i], val, "T") ? pdf.getStringHeight(col_widths[i], val, "T") : max_height
			#max_height = (pdf.GetY - base_y) if (pdf.GetY - base_y) > max_height
			pdf.SetXY(col_x + col_widths[i], base_y);
		end
		return max_height
	end
	#new page logo
	def render_newpage(pdf,orientation,logo,page_width)
		pdf.AddPage(orientation)
		if !logo.blank? && (File.exist? (Redmine::Plugin.public_directory + "/redmine_wktime/images/" + logo))
			pdf.Image(Redmine::Plugin.public_directory + "/redmine_wktime/images/" + logo, page_width-50, 10,40,25)
			pdf.Ln
			pdf.SetY(pdf.GetY+25)
		end
	end
	
	def getKey(entry,unitLabel)
		cf_in_row1_value = nil
		cf_in_row2_value = nil
		key = entry.project.id.to_s + (entry.issue.blank? ? '' : entry.issue.id.to_s) + (entry.activity.blank? ? '' : entry.activity.id.to_s) + (unitLabel.blank? ? '' : entry.currency.to_s)
		entry.custom_field_values.each do |custom_value|			
			custom_field = custom_value.custom_field
			if (!Setting.plugin_redmine_wktime['wktime_enter_cf_in_row1'].blank? &&	Setting.plugin_redmine_wktime['wktime_enter_cf_in_row1'].to_i == custom_field.id)
				cf_in_row1_value = custom_value.to_s
			end
			if (!Setting.plugin_redmine_wktime['wktime_enter_cf_in_row2'].blank? && Setting.plugin_redmine_wktime['wktime_enter_cf_in_row2'].to_i == custom_field.id)
				cf_in_row2_value = custom_value.to_s	
			end
		end
		if (!cf_in_row1_value.blank?)
			key = key + cf_in_row1_value
		end
		if (!cf_in_row2_value.blank?)
			key = key + cf_in_row2_value
		end
		if (!Setting.plugin_redmine_wktime['wktime_enter_comment_in_row'].blank? && Setting.plugin_redmine_wktime['wktime_enter_comment_in_row'].to_i == 1)	
			if(!entry.comments.blank?)
				key = key + entry.comments				
			end			
		end
		key
	end
	
	def getWeeklyView(entries, unitLabel, sumHours = false, startOfSheet, vwFrequency)
		weeklyHash = Hash.new
		prev_entry = nil		
		entries.each do |entry|
			# If a project is deleted all its associated child table entries will get deleted except wk_expense_entries
			# So added !entry.project.blank? check to remove deleted projects
			if !entry.project.blank?		
				key = getKey(entry,unitLabel)
				hourMatrix = weeklyHash[key]				
				if hourMatrix.blank?
					#create a new matrix if not found
					hourMatrix =  []
					rows = []
					hourMatrix[0] = rows
					weeklyHash[key] = hourMatrix
				end
				
				unless startOfSheet.blank?
					startOfWeek = startOfSheet
				else
					#Martin Dube contribution: 'start of the week' configuration
					#wday returns 0 - 6, 0 is sunday
					startOfWeek = getStartOfWeek
				end
				#index = (entry.spent_on.wday+7-(startOfWeek))%7
				index = (entry.spent_on.wday+vwFrequency-(startOfWeek))%vwFrequency
				updated = false
				hourMatrix.each do |rows|
					if rows[index].blank?
						rows[index] = entry
						updated = true
						break
					else 
						if sumHours
							tempEntry = rows[index]
							tempEntry.hours += entry.hours
							updated = true
							break
						end
					end
				end
				if !updated
					rows = []
					hourMatrix[hourMatrix.size] = rows
					rows[index] = entry
				end
			end
		end
		return weeklyHash
	end

def getColumnValues(matrix, totals, unitLabel,rowNumberRequired, j=0, includeComments=false)
	col_values = []
	matrix_values = []
	k=0
	unless matrix.blank?
		matrix.each do |rows|
			issueWritten = false
			col_values = []
			matrix_values << col_values
			hoursIndex = 3
			if rowNumberRequired
				col_values[0] = (j+1).to_s
				k=1
			end
			
			rows.each.with_index do |entry, i|
				unless entry.blank?
					if !issueWritten
						col_values[k] = entry.project.name
						col_values[k+1] = entry.issue.blank? ? "" : entry.issue.subject
						col_values[k+2] = entry.activity.blank? ? "" : entry.activity.name
						currencyColIndex = k+3
						if includeComments && (!Setting.plugin_redmine_wktime['wktime_enter_comment_in_row'].blank? &&
						Setting.plugin_redmine_wktime['wktime_enter_comment_in_row'].to_i == 1)
							col_values[k+3]= entry.comments
							currencyColIndex = k+4
						end
						if !unitLabel.blank?
							col_values[currencyColIndex]= entry.currency
						end
						custom_field_values = entry.custom_field_values
						set_cf_value(col_values, custom_field_values, 'wktime_enter_cf_in_row1')	
						set_cf_value(col_values, custom_field_values, 'wktime_enter_cf_in_row2')	
						hoursIndex = col_values.size
						issueWritten = true
						j += 1
					end
					col_values[hoursIndex+i] =  (entry.hours.blank? ? "" : ("%.2f" % entry.hours.to_s))
					totals[i] += entry.hours unless entry.hours.blank?
				end
			end
		end
	end	
	return matrix_values, j
end

def getTotalValues(totals, hoursIndex,unit)
	grand_total = 0.0
	totals.each { |t| grand_total += t }
	#project, issue, is blank, and then total
	total_values = []
	for i in 0..hoursIndex-2
		total_values << ""
	end
	total_values << "#{l(:label_total)} = #{unit} #{("%.2f" % grand_total)}"
	#concatenate two arrays
	total_values += totals.collect{ |t| "#{unit} #{("%.2f" % t.to_s)}"}
	return total_values
end

	
	def render_table_header(pdf, columns, col_width, row_height, table_width)
        # headers
        pdf.SetFontStyle('B',8)
        pdf.SetFillColor(230, 230, 230)

        # render it background to find the max height used
        base_x = pdf.GetX
        base_y = pdf.GetY
        max_height = wktime_to_pdf_write_cells(pdf, columns, col_width, row_height)
        #pdf.Rect(base_x, base_y, table_width + col_id_width, max_height, 'FD');
		pdf.Rect(base_x, base_y, table_width, max_height, 'FD');
        pdf.SetXY(base_x, base_y);

        # write the cells on page
        wktime_to_pdf_write_cells(pdf, columns, col_width, row_height)
        issues_to_pdf_draw_borders(pdf, base_x, base_y, base_y + max_height,0, col_width)
        pdf.SetY(base_y + max_height);

        # rows
        pdf.SetFontStyle('',8)
        pdf.SetFillColor(255, 255, 255)
    end

	def render_header(pdf, entries, user, startday, row_height,title)
		base_x = pdf.GetX
		base_y = pdf.GetY
		  
		# title
		pdf.SetFontStyle('B',11)
		pdf.RDMCell(100,10, title)
		pdf.SetXY(base_x, pdf.GetY+row_height)
		
		render_header_elements(pdf, base_x, pdf.GetY+row_height, l(:field_name), user.name)
		#render_header_elements(pdf, base_x, pdf.GetY+row_height, l(:field_project), entries.blank? ? "" : entries[0].project.name)
		render_header_elements(pdf, base_x, pdf.GetY+row_height, l(:label_week), startday.to_s + " - " + (startday+6).to_s)
		render_customFields(pdf, base_x, user, startday, row_height)
		pdf.SetXY(base_x, pdf.GetY+row_height)
	end
	
	def render_customFields(pdf, base_x, user, startday, row_height)
		if !@wktime.blank? && !@wktime.custom_field_values.blank?
			@wktime.custom_field_values.each do |custom_value|
				render_header_elements(pdf, base_x, pdf.GetY+row_height, 
					custom_value.custom_field.name, custom_value.value)
			end
		end
	end
	
	def render_header_elements(pdf, x, y, element, value="")

		pdf.SetXY(x, y)
		unless element.blank?
			pdf.SetFontStyle('B',8)
			pdf.RDMCell(50,10, element)
			pdf.SetXY(x+40, y)
			pdf.RDMCell(10,10, ":")
			pdf.SetFontStyle('',8)
			pdf.SetXY(x+40+2, y)
		end
		pdf.RDMCell(50,10, value)

	end
	
	def render_signature(pdf, page_width, table_width, row_height,bottom_margin,page_height,orientation,logo)
		base_x = pdf.GetX
		base_y = pdf.GetY
		
		submissionAck   = Setting.plugin_redmine_wktime['wktime_submission_ack']
		
		unless submissionAck.blank?
			check_render_newpage(pdf,page_height,row_height,bottom_margin,submissionAck,orientation,logo,page_width)
			#pdf.SetY(base_y + row_height)
			#pdf.SetXY(base_x, pdf.GetY+row_height)
			#to wrap text and to put it in multi line use MultiCell
			pdf.RDMMultiCell(table_width,5, submissionAck)
			submissionAck= nil
		end
		check_render_newpage(pdf,page_height,row_height,bottom_margin,submissionAck,orientation,logo,page_width)
		
		pdf.SetFontStyle('B',8)
		pdf.SetXY(page_width-90, pdf.GetY+row_height)
		pdf.RDMCell(50,10, l(:label_wk_signature) + " :")
		pdf.SetXY(page_width-90, pdf.GetY+(2*row_height))
		pdf.RDMCell(100,10, l(:label_wk_submitted_by) + " ________________________________")
		pdf.SetXY(page_width-90, pdf.GetY+ (2*row_height))
		pdf.RDMCell(100,10, l(:label_wk_approved_by) + " ________________________________")
	end
	#check_render_newpage
	def check_render_newpage(pdf,page_height,row_height,bottom_margin,submissionAck,orientation,logo,page_width)
		base_y = pdf.GetY
		if(!submissionAck.blank?)
			space_left = page_height - (base_y+(7*row_height)) - bottom_margin
		else
			space_left = page_height - (base_y+(5*row_height)) - bottom_margin
		end
		if(space_left<0)
			render_newpage(pdf,orientation,logo,page_width)
		end
	end
	def set_cf_header(columns, col_width, setting_name)
		cf_value = nil
		if !Setting.plugin_redmine_wktime[setting_name].blank? && !@new_custom_field_values.blank? &&
			(cf_value = @new_custom_field_values.detect { |cfv| 
				cfv.custom_field.id == Setting.plugin_redmine_wktime[setting_name].to_i }) != nil
				
				columns << cf_value.custom_field.name
				unless col_width.blank?
					old_total = 0
					new_total = 0
					for i in 0..col_width.size-1
						old_total += col_width[i]
						if i == 1
							col_width[i] -= col_width[i]*10/100
						else
							col_width[i] -= col_width[i]*20/100
						end
						new_total += col_width[i]
					end
					# reset width 15% for project, 55% for issue, 15% for activity
					#col_width[0] *= 0.75
					#col_width[1] *= 0.9
					#col_width[2] *= 0.75
					
					col_width << old_total - new_total
				end
		end
	end

	def set_cf_value(col_values, custom_field_values, setting_name)	
		cf_value = nil
		if !Setting.plugin_redmine_wktime[setting_name].blank? &&
				(cf_value = custom_field_values.detect { |cfv| 
					cfv.custom_field.id == Setting.plugin_redmine_wktime[setting_name].to_i }) != nil
					col_values << cf_value.value
		end
	end
	
	def getTimeEntryStatus(spent_on,user_id)
		#result = Wktime.find(:all, :conditions => [ 'begin_date = ? AND user_id = ?', getStartDay(spent_on), user_id])	
		start_day = getStartDay(spent_on)	
		locked  = isLocked(start_day)
		#locked = call_hook(:controller_check_locked,{ :startdate => start_day})
		locked  = locked.blank? ? '' : (locked.is_a?(Array) ? (locked[0].blank? ? '': locked[0].to_s) : locked.to_s) 
		locked = ( !locked.blank? && to_boolean(locked))
		if locked
			result = 'l'
		else		
			result = Wktime.where(['begin_date = ? AND user_id = ?', start_day, user_id])
			result = result[0].blank? ? 'n' : result[0].status
		end
		return 	result		
	end
	
	def time_expense_tabs
		if params[:controller] == "wktime" || params[:controller] == "wkexpense" 
			tabs = [
				{:name => 'wktime', :partial => 'wktime/tab_content', :label => :label_wktime},
				{:name => 'wkexpense', :partial => 'wktime/tab_content', :label => :label_wkexpense}
			   ]
		 elsif params[:controller] == "wkattendance" || params[:controller] == "wkpayroll" || params[:controller] == "wkscheduling"  || params[:controller] == "wkschedulepreference" || params[:controller] == "wkshift" || params[:controller] == "wkpublicholiday" || params[:controller] == "wksurvey"
				tabs = []
				if showAttendance
					tabs << {:name => 'leave', :partial => 'wktime/tab_content', :label => :label_wk_leave}
					tabs <<	{:name => 'clock', :partial => 'wktime/tab_content', :label => :label_clock}
					tabs <<	{:name => 'wkpublicholiday', :partial => 'wktime/tab_content', :label => :label_public_holiday}
					
				end	
				
				if showPayroll
					tabs << {:name => 'payroll', :partial => 'wktime/tab_content', :label => :label_payroll}
					#tabs <<	{:name => 'usersettings', :partial => 'wktime/tab_content', :label => :label_payroll_settings}
				end
				
				if showShiftScheduling
					tabs <<  {:name => 'wkscheduling', :partial => 'wktime/tab_content', :label => :label_scheduling}
				end
				
				if showSurvey
					tabs << {:name => 'wksurvey', :partial => 'wktime/tab_content', :label => :label_survey}
				end
		elsif params[:controller] == "wklead" || params[:controller] == "wkcrmaccount" || params[:controller] == "wkopportunity" || params[:controller] == "wkcrmactivity" || params[:controller] == "wkcrmcontact"
			tabs = [
				{:name => 'wklead', :partial => 'wktime/tab_content', :label => :label_lead_plural},
				{:name => 'wkcrmaccount', :partial => 'wktime/tab_content', :label => :label_accounts},
				{:name => 'wkopportunity', :partial => 'wktime/tab_content', :label => :label_opportunity_plural},
				{:name => 'wkcrmactivity', :partial => 'wktime/tab_content', :label => :label_activity_plural},
				{:name => 'wkcrmcontact', :partial => 'wktime/tab_content', :label => :label_contact_plural}
			   ]
		
		elsif params[:controller] == "wkinvoice" || params[:controller] == "wkcontract" || params[:controller] == "wkpayment" 		
			tabs = [
				{:name => 'wkinvoice', :partial => 'wktime/tab_content', :label => :label_invoice},
				{:name => 'wkpayment', :partial => 'wktime/tab_content', :label => :label_payments},
				{:name => 'wkcontract', :partial => 'wktime/tab_content', :label => :label_contracts}
			   ]
		elsif params[:controller] == "wkgltransaction" || params[:controller] == "wkledger"
			tabs = [
				{:name => 'wkgltransaction', :partial => 'wktime/tab_content', :label => :label_transaction},
				{:name => 'wkledger', :partial => 'wktime/tab_content', :label => :label_ledger}
			   ]
		elsif params[:controller] == "wkrfq" || params[:controller] == "wkquote" || params[:controller] == "wkpurchaseorder" || params[:controller] == "wksupplierinvoice" || params[:controller] == "wksupplierpayment" || params[:controller] == "wksupplieraccount" || params[:controller] == "wksuppliercontact"
			tabs = [
				{:name => 'wkrfq', :partial => 'wktime/tab_content', :label => :label_rfq},
				{:name => 'wkquote', :partial => 'wktime/tab_content', :label => :label_quotes},
				{:name => 'wkpurchaseorder', :partial => 'wktime/tab_content', :label => :label_purchase_order},
				{:name => 'wksupplierinvoice', :partial => 'wktime/tab_content', :label => :label_supplier_invoice},
				{:name => 'wksupplierpayment', :partial => 'wktime/tab_content', :label => :label_supplier_payment},
				{:name => 'wksupplieraccount', :partial => 'wktime/tab_content', :label => :label_supplier_account},
				{:name => 'wksuppliercontact', :partial => 'wktime/tab_content', :label => :label_supplier_contact}
			   ]
		elsif params[:controller] == "wkcrmenumeration" || params[:controller] == "wktax" || params[:controller] == "wkexchangerate" || params[:controller] == "wklocation" || params[:controller] == "wkgrouppermission"
			tabs = [
				{:name => 'wkcrmenumeration', :partial => 'wktime/tab_content', :label => :label_enumerations},
				{:name => 'wklocation', :partial => 'wktime/tab_content', :label => :label_location},
				{:name => 'wktax', :partial => 'wktime/tab_content', :label => :label_tax},
				{:name => 'wkexchangerate', :partial => 'wktime/tab_content', :label => :label_exchange_rate},
				{:name => 'wkgrouppermission', :partial => 'wktime/tab_content', :label => :label_permissions}
				
			   ]
		else
			tabs = [
				{:name => 'wkproduct', :partial => 'wktime/tab_content', :label => :label_product},
				{:name => 'wkproductitem', :partial => 'wktime/tab_content', :label => :label_item},
				{:name => 'wkshipment', :partial => 'wktime/tab_content', :label => :label_shipment},
				{:name => 'wkasset', :partial => 'wktime/tab_content', :label => :label_asset},
				{:name => 'wkassetdepreciation', :partial => 'wktime/tab_content', :label => :label_depreciation}
			   ]
		end
		tabs
	end		
	
	#change the date to first day of week
	def getStartDay(date)	
		startOfWeek = getStartOfWeek
		#Martin Dube contribution: 'start of the week' configuration
		unless date.nil?			
			#the day of calendar week (0-6, Sunday is 0)			
			dayfirst_diff = (date.wday+7) - (startOfWeek)
			date -= (dayfirst_diff%7)
		end		
		date
	end
	
	#Code snippet taken from application_helper.rb  - include_calendar_headers_tags method
	def getStartOfWeek
		start_of_week = Setting.start_of_week
        start_of_week = l(:general_first_day_of_week, :default => '1') if start_of_week.blank?    
		start_of_week = start_of_week.to_i % 7
	end
	
	def sendNonSubmissionMail
		startDate = getStartDay(Date.today)
		deadline = Date.today	
		#No. of working days between startOfWeek and submissionDeadline					
		diff = working_days(startDate,deadline + 1)
		countOfWorkingDays = 7 - (Setting.non_working_week_days).size		
		if diff != countOfWorkingDays
			startDate = startDate-7
		end
		
		nonSubmissionUserIds = getNonSubmissionUserIds
		queryStr =  "select distinct u.* from projects p" +
		 " inner join members m on p.id = m.project_id and p.status not in (#{Project::STATUS_CLOSED},#{Project::STATUS_ARCHIVED})"  +
		 " inner join member_roles mr on m.id = mr.member_id" +
		 " inner join roles r on mr.role_id = r.id and r.permissions like '%:log_time%'" +
		 " inner join users u on m.user_id = u.id and u.status = #{User::STATUS_ACTIVE}" +
		 " left outer join wktimes w on u.id = w.user_id and w.begin_date = '" + startDate.to_s + "'" +
		 " where (w.status is null or w.status = 'n') "
		
		if !nonSubmissionUserIds.blank?
			queryStr += "and u.id in (#{nonSubmissionUserIds})"
		end
		users = User.find_by_sql(queryStr)
		users.each do |user|
			WkMailer.nonSubmissionNotification(user,startDate).deliver
		end
	end
	
	def getDateSqlString(dtfield)
		startOfWeek = getStartOfWeek

		# postgre doesn't have the weekday function
		# The day of the week (0 - 6; Sunday is 0)
		if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'			 
			sqlStr = dtfield + " - ((cast(extract(dow from " + dtfield + ") as integer)+7-" + startOfWeek.to_s + ")%7)"			 
		elsif ActiveRecord::Base.connection.adapter_name == 'SQLite'			 
			sqlStr = "date(" + dtfield  + " , '-' || ((strftime('%w', " + dtfield + ")+7-" + startOfWeek.to_s + ")%7) || ' days')"
		elsif ActiveRecord::Base.connection.adapter_name == 'SQLServer'		
			sqlStr = "DateAdd(d, (((((DATEPART(dw," + dtfield + ")-1)%7)-1)+(8-" + startOfWeek.to_s + ")) % 7)*-1," + dtfield + ")"
		else
			# mysql - the weekday index for date (0 = Monday, 1 = Tuesday, � 6 = Sunday)
			sqlStr = "adddate(" + dtfield + ",mod(weekday(" + dtfield + ")+(8-" + startOfWeek.to_s + "),7)*-1)"
		end		
		sqlStr
	end
	
	def getHostAndDir(req)		
		"#{req.url}".gsub("#{req.path_info}","").gsub("#{req.protocol}","")	
	end	
	
	def getNonWorkingDayColumn(startDate)	
		startOfWeek = getStartOfWeek
		ndays = Setting.non_working_week_days
		columns =''
		ndays.each do |day|
			columns << ',' if !columns.blank?
			columns << ((((day.to_i +7) - startOfWeek ) % 7) + 1).to_s
		end
		publicHolidayColumn = getPublicHolidayColumn(startDate)		
		publicHolidayColumn = publicHolidayColumn.join(',') if !publicHolidayColumn.nil?		
		columns << ","  if !publicHolidayColumn.blank? && !columns.blank?
		columns << publicHolidayColumn if !publicHolidayColumn.blank? 		
		columns
	end
	
	def settings_tabs		   
		tabs = [
				{:name => 'general', :partial => 'settings/tab_general', :label => :label_general},
				{:name => 'wktime_settings', :partial => 'settings/tab_time', :label => :label_te},
				{:name => 'attendance', :partial => 'settings/tab_attendance', :label => :report_attendance},
				{:name => 'payroll_settings', :partial => 'settings/tab_payroll', :label => :label_payroll},
				{:name => 'billing', :partial => 'settings/tab_billing', :label => :label_wk_billing},
				{:name => 'purchase', :partial => 'settings/tab_purchase', :label => :label_purchasing},
				{:name => 'inventory', :partial => 'settings/tab_inventory', :label => :label_inventory}
				#{:name => 'shiftscheduling', :partial => 'settings/tab_shift_scheduling', :label => :label_scheduling}
			   ]	
	end	
	
	def getPublicHolidays()
		holidays = nil
		publicHolidayList = Setting.plugin_redmine_wktime['wktime_public_holiday']	
		if !publicHolidayList.blank?
			holidays = Array.new
			publicHolidayList.each do |holiday|				
				holidays << holiday.split('|')[0].strip
			end		
		end		
		holidays				
	end
	
	def checkHoliday(timeEntryDate,publicHolidays)	
		isHoliday = false	
		if !publicHolidays.nil? 		
			isHoliday = true if publicHolidays.include? timeEntryDate		
		end		
		isHoliday
	end
	
	def getPublicHolidayColumn(date)		
		columns =nil
		startDate = getStartDay(date.to_date)
		publicHolidays = getPublicHolidays()	
		if !publicHolidays.nil? 
			columns = Array.new
			for i in 0..6				
				columns << (i+1).to_s if checkHoliday((startDate.to_date + i).to_s,publicHolidays)	
			end	
		end		
		columns
	end
	
	# Returns week day of public holiday
	# mon - sun --> 1 - 7
	def getWdayForPublicHday(startDate)
		pHdays = getPublicHolidays()
		wDayOfPublicHoliday = Array.new
		if !pHdays.blank?		
			for i in 0..6
				wDayOfPublicHoliday << ((startDate+i).cwday).to_s if checkHoliday((startDate + i).to_s,pHdays)
			end
		end	
		wDayOfPublicHoliday
	end
	
	def checkViewPermission
		ret =  false
		if User.current.logged?
			viewProjects = Project.where(Project.allowed_to_condition(User.current, :view_time_entries ))
			loggableProjects ||= Project.where(Project.allowed_to_condition(User.current, :log_time))
			# viewMenu = call_hook(:view_wktime_menu)
			# viewMenu  = viewMenu.blank? ? '' : (viewMenu.is_a?(Array) ? (viewMenu[0].blank? ? '': viewMenu[0].to_s) : viewMenu.to_s) 
			#@manger_user = (!viewMenu.blank? && to_boolean(viewMenu))	
			ret = (!viewProjects.blank? && viewProjects.size > 0) || (!loggableProjects.blank? && loggableProjects.size > 0) || validateERPPermission('A_TE_PRVLG') || (isSupervisorApproval && getSuperViewPermission) #(!viewMenu.blank? && to_boolean(viewMenu))
		end
		ret
	end
	
	def is_number(val)
		true if Float(val) rescue false
	end
	
	def to_boolean(str)
      str == 'true'
    end
	
	def getStatus_Project_Issue(issue_id,project_id)
		if !issue_id.blank?
			cond = getIssueSqlString(issue_id)
		end
		if !project_id.blank?
			cond = getProjectSqlString(project_id)
		end		
		sDay = getDateSqlString('t.spent_on')
		time_sqlStr = " SELECT t.* FROM time_entries t inner join wktimes w on w.begin_date =  #{ sDay} and w.user_id =t.user_id #{cond}"		
		time_entry = TimeEntry.find_by_sql(time_sqlStr)
		expense_sqlStr = " SELECT t.* FROM wk_expense_entries t inner join wkexpenses w on w.begin_date =  #{ sDay} and w.user_id =t.user_id #{cond}"
		expense_entry = WkExpenseEntry.find_by_sql(expense_sqlStr)
		ret = (!time_entry.blank? && time_entry.size > 0) ||  (!expense_entry.blank? && expense_entry.size > 0)
	end
	
	def getIssueSqlString(issue_id)
		" where t.issue_id = #{issue_id} and (w.status ='s' OR w.status ='a')"
	end
	
	def getProjectSqlString(project_id)
		" where t.project_id = #{project_id} and (w.status ='s' OR w.status ='a')"
	end

	def getAccountUserProjects
		Project.where(:status => "#{Project::STATUS_ACTIVE}").order('name')
	end
	
	def getAddDateStr(dtfield,noOfDays)
		if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'			 
			dateSqlStr = "date('#{dtfield}') + "	+ noOfDays.to_s
		elsif ActiveRecord::Base.connection.adapter_name == 'SQLite'			 
			dateSqlStr = "date('#{dtfield}' , '+' || " + "(#{noOfDays.to_s})" + " || ' days')"
		elsif ActiveRecord::Base.connection.adapter_name == 'SQLServer'		
			dateSqlStr = "DateAdd(d, " + noOfDays.to_s + ",'#{dtfield}')"
		else
			dateSqlStr = "adddate('#{dtfield}', " + noOfDays.to_s + ")"
		end		
		dateSqlStr
	end
	
	def getAddMonthDateStr(dtfield,intervalVal,intervalType)
		interval = getIntervalFormula(intervalVal)
		if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'			 
			dateSqlStr = "date('#{dtfield}') + interval '1 month' * "	+ interval.to_s
		elsif ActiveRecord::Base.connection.adapter_name == 'SQLite'			 
			dateSqlStr = "date('#{dtfield}' , '+' || " + "(#{interval.to_s})" + " || ' months')"
		elsif ActiveRecord::Base.connection.adapter_name == 'SQLServer'		
			dateSqlStr = "DateAdd(m, " + interval.to_s + ",'#{dtfield}')"
		else
			dateSqlStr = "adddate('#{dtfield}', " + interval.to_s + " MONTH )"
		end		
		dateSqlStr
	end
	
	def getIntervalFormula(intervalVal)
		(t4.i*intervalVal*10000 + t3.i*intervalVal*1000 + t2.i*intervalVal*100 + t1.i*intervalVal*10 + t0.i*intervalVal)
	end
	
	def getConvertDateStr(dtfield)		
		if ActiveRecord::Base.connection.adapter_name == 'SQLServer'		
			dateSqlStr = "cast(#{dtfield} as date)"
		else
			# For MySQL, PostgreSQL, SQLite
			dateSqlStr = "date(#{dtfield})"
		end
		dateSqlStr
	end
	
	def getValidUserCF(userCFHash, userCF)
		tmpUserCFHash = userCFHash
		if !userCF.blank? && !userCFHash.blank?
			cfHash = Hash.new
			userCF.each do |cf|
				cfHash["user.cf_#{cf.id}"] = "#{cf.name}"
			end
			userCFHash.each_key do |key|
				if !cfHash.has_key?(key)
					tmpUserCFHash.delete(key)
				end
			end
		end
		tmpUserCFHash
	end
	
	#Luna Lenardi contribution
	def number_currency_format_unit
		begin
			l('number.currency.format.unit')
		rescue
			'$'
		end
	end
	
	def getNonSubmissionUserIds
		groupusers = Array.new
		nonSubmissionUserIds = Array.new
		userIds = ""
		accountGrpIds = Setting.plugin_redmine_wktime['wktime_approval_groups'] if !Setting.plugin_redmine_wktime['wktime_approval_groups'].blank?
		if !accountGrpIds.blank?
			accountGrpIds = accountGrpIds.collect{|i| i.to_i}
		end
		if !accountGrpIds.blank?
			accountGrpIds.each do |group_id|
			scope = User.in_group(group_id) 
			groupusers << scope.all
			end
		end
		grpUserIds = Array.new
		grpids = ""
		count = 0
		nonSubmissionUserIds = []
		if !accountGrpIds.include?(0)
			begin
				nonSubmissionUserIds = nonSubmissionUserIds + groupusers[count].collect{|user| user.id}.uniq if !groupusers.blank? && !groupusers[count].blank?	
				count += 1
			end until count == groupusers.length
			userIds = nonSubmissionUserIds.empty? ? -1 : nonSubmissionUserIds.join(",")
		end
		userIds
	end
	
	def findLastAttnEntry(isCurrentUser)
		if isCurrentUser
			lastAttnEntries = WkAttendance.find_by_sql("select a.* from wk_attendances a inner join ( select max(start_time) as start_time,user_id from wk_attendances where user_id = #{User.current.id} group by user_id ) vw on a.start_time = vw.start_time and a.user_id = vw.user_id order by a.start_time ")
		else
			lastAttnEntries = WkAttendance.find_by_sql("select a.* from wk_attendances a inner join ( select max(start_time) as start_time,user_id from wk_attendances group by user_id ) vw on a.start_time = vw.start_time and a.user_id = vw.user_id order by a.start_time ")
		end
		lastAttnEntries
	end	
	
	def computeWorkedHours(startTime,endTime, ishours)
		currentEntryDate = startTime.localtime
		workedHours = endTime-startTime
		if !Setting.plugin_redmine_wktime['wktime_break_time'].blank?
			Setting.plugin_redmine_wktime['wktime_break_time'].each_with_index do |element,index|
			  listboxArr = element.split('|')
			  breakStart = currentEntryDate.change({ hour: listboxArr[0], min: listboxArr[1], sec: 0 })
			  breakEnd = currentEntryDate.change({ hour: listboxArr[2], min:listboxArr[3], sec: 0 })
			  if(!(startTime>breakEnd || endTime < breakStart))
				if startTime < breakStart
					if endTime < breakEnd
						workedHours = workedHours - (endTime-breakStart)
					else
						workedHours = workedHours - (breakEnd-breakStart)
					end
				else
					if endTime > breakEnd
						workedHours = workedHours - (breakEnd-startTime)
					else
						workedHours = nil
					end
				end
			  end
			end
		end
		if ishours
			workedHours = (workedHours/1.hour).round(2) unless workedHours.blank?
		end
		workedHours
	end
	
	def totalhours
		dateStr = getConvertDateStr('start_time')
		(WkAttendance.where("user_id = #{User.current.id} and #{dateStr} = '#{Time.now.strftime("%Y-%m-%d")}'").sum(:hours)).round(2)
	end
	
	def showExpense
		!Setting.plugin_redmine_wktime['wktime_enable_expense_module'].blank? &&
			Setting.plugin_redmine_wktime['wktime_enable_expense_module'].to_i == 1
	end
	
	def showAttendance
		!Setting.plugin_redmine_wktime['wktime_enable_attendance_module'].blank? &&
			Setting.plugin_redmine_wktime['wktime_enable_attendance_module'].to_i == 1 
	end
	
	def showReports
		!Setting.plugin_redmine_wktime['wktime_enable_report_module'].blank? &&
			Setting.plugin_redmine_wktime['wktime_enable_report_module'].to_i == 1
	end
	
	def getTEAllTimeRange(ids)
		teQuery = "select v.startday as startday from (select #{getDateSqlString('t.spent_on')} as startday " +
				"from time_entries t where user_id in (#{ids})) v group by v.startday order by v.startday"
		teResult = TimeEntry.find_by_sql(teQuery)
	end
	
	def getAttnAllTimeRange(ids)
		dateStr = getConvertDateStr('start_time')
		teQuery = "select (#{dateStr}) as startday from wk_attendances w where user_id in (#{ids}) order by #{dateStr} "
		teResult = WkAttendance.find_by_sql(teQuery)
	end
	
	def getUserAllTimeRange(ids)
		dateStr = getConvertDateStr('min(created_on)')
		usrQuery = "select (#{dateStr}) as startday from users where id in (#{ids})"
		usrResult = User.find_by_sql(usrQuery)
	end
	
	#This function used in Time & Attendance Module
	def getAllTimeRange(ids, isTime)
		teResult = isTime ? getTEAllTimeRange(ids) : getAttnAllTimeRange(ids)		
		usrResult = getUserAllTimeRange(ids)
		currentWeekEndDay = getEndDay(Date.today)
		@from = getStartDay(Date.today)
		@to = currentWeekEndDay
		if !teResult.blank? && teResult.size > 0
			@from = (teResult[0].startday).to_date
			@to = (teResult[teResult.size - 1].startday).to_date + 6			
			if currentWeekEndDay > @to
				@to = currentWeekEndDay
			end
		end
		if !usrResult.blank? && usrResult.size > 0
			stDate = (usrResult[0].startday)
			stDate = getStartDay(stDate.to_date) if !stDate.blank? && isTime
			if (!stDate.blank? && stDate.to_date < @from.to_date)
				@from = stDate
			end
		end		
	end
	
	#change the date to a last day of week
	def getEndDay(date)
		start_of_week = getStartOfWeek
		#Martin Dube contribution: 'start of the week' configuration
		unless date.nil?
			daylast_diff = (6 + start_of_week) - date.wday
			date += (daylast_diff%7)
		end
		date
	end
	
	 # Returns the options for the date_format setting
    def date_format_options
		Import::DATE_FORMATS.map do |f|
		  format = f.gsub('%', '').gsub(/[dmY]/) do
			{'d' => 'DD', 'm' => 'MM', 'Y' => 'YYYY'}[$&]
		  end
		  [format+" HH:MM:SS", f + " %T"]
		end
	end
	
	def showPayroll
		!Setting.plugin_redmine_wktime['wktime_enable_payroll_module'].blank? &&
			Setting.plugin_redmine_wktime['wktime_enable_payroll_module'].to_i == 1
	end
	
	def showSurvey
		!Setting.plugin_redmine_wktime['wktime_enable_survey_module'].blank? &&
			Setting.plugin_redmine_wktime['wktime_enable_survey_module'].to_i == 1
    end
	
	def showBilling
		(!Setting.plugin_redmine_wktime['wktime_enable_billing_module'].blank? &&
			Setting.plugin_redmine_wktime['wktime_enable_billing_module'].to_i == 1 ) #&& isModuleAdmin('wktime_billing_groups')			
	end
	
	# Return the given type of custom Fields array
	# Used in plugin settings
	def getCfListArr(customFields, cfType, needBlank)
		unless customFields.blank?
			cfs = customFields.select {|cf| cf.field_format == cfType }
			unless cfs.blank?
				cfArray = cfs.collect {|cf| [cf.name, cf.id] }
			else
				cfArray = Array.new
			end
		else
			cfArray = Array.new
		end
		cfArray.unshift(["",0]) if needBlank
		cfArray
	end
	
	def getPluginSetting(setting_name)
		Setting.plugin_redmine_wktime[setting_name]
	end
	
	def isModuleAdmin(settings)
		group = nil
		isbillingUser = false
		groupusers = Array.new
		billingGrpId = getSettingCfId(settings)
		if !billingGrpId.blank? && billingGrpId != 0
				scope = User.in_group(billingGrpId)	
				groupusers << scope.all
		end
		grpUserIds = Array.new		
		grpUserIds = groupusers[0].collect{|user| user.id}.uniq if !groupusers.blank? && !groupusers[0].blank?
		isbillingUser = grpUserIds.include?(User.current.id)
	end
	
	def getSettingCfId(settingId)
		cfId = Setting.plugin_redmine_wktime[settingId].blank? ? 0 : Setting.plugin_redmine_wktime[settingId].to_i
		cfId
	end
	
	def isBilledTimeEntry(tEntry)
		ret = false
		unless tEntry.blank?
			#cfEntry = tEntry.custom_value_for(getSettingCfId('wktime_billing_id_cf'))
			spentFor = tEntry.spent_for
			ret = true unless spentFor.blank? || spentFor.invoice_item_id.blank?
		end
		ret
	end
	
	def showAccounting
		(!Setting.plugin_redmine_wktime['wktime_enable_accounting_module'].blank? &&
			Setting.plugin_redmine_wktime['wktime_enable_accounting_module'].to_i == 1 ) && (validateERPPermission("B_ACC_PRVLG") || validateERPPermission("A_ACC_PRVLG"))
	end
	
	def isChecked(settingName)
		(!Setting.plugin_redmine_wktime[settingName].blank? && Setting.plugin_redmine_wktime[settingName].to_i == 1)
	end
	
	def showCRMModule
		(!Setting.plugin_redmine_wktime['wktime_enable_crm_module'].blank? &&
			Setting.plugin_redmine_wktime['wktime_enable_crm_module'].to_i == 1 ) && (validateERPPermission("B_CRM_PRVLG") || validateERPPermission("A_CRM_PRVLG"))
	end
	
	def getGroupUserIdsArr(groupId)
		userIdArr = User.in_group(groupId).all.pluck(:id)
		userIdArr
	end
	
	def getGroupUserArr(shortName)
		userIdArr = Array.new
		userIds = WkPermission.joins("INNER JOIN wk_group_permissions AS GP ON wk_permissions.id = permission_id ")
							   .joins("INNER JOIN groups_users AS GU ON GP.group_id = GU.group_id")
							   .joins("INNER JOIN users AS U ON GU.user_id = U.id")
							   .where("short_name = ?", shortName)
							   .select("U.id, U.firstname, U.lastname")
		if !userIds.blank?
			userIds.each do | entry|				
				userIdArr <<  [(entry.firstname + " " + entry.lastname), entry.id  ]
			end
		end
		userIdArr
	end
	
	def groupOfUsers
		grpArr = nil
		grpArr = (getGroupUserArr('B_CRM_PRVLG') + 
				 getGroupUserArr('A_CRM_PRVLG')).uniq
		grpArr.unshift(["",0]) 
			
		grpArr
	end
	
	def showTimeExpense
		(!Setting.plugin_redmine_wktime['wktime_enable_time_module'].blank? &&
			Setting.plugin_redmine_wktime['wktime_enable_time_module'].to_i == 1) || 
			(!Setting.plugin_redmine_wktime['wktime_enable_expense_module'].blank? &&
			Setting.plugin_redmine_wktime['wktime_enable_expense_module'].to_i == 1) ||
			# if none of the settings is checked
			( (Setting.plugin_redmine_wktime['wktime_enable_dashboards_module'].blank? ||
			Setting.plugin_redmine_wktime['wktime_enable_dashboards_module'].to_i == 0) &&
			(Setting.plugin_redmine_wktime['wktime_enable_time_module'].blank? ||
			Setting.plugin_redmine_wktime['wktime_enable_time_module'].to_i == 0) &&
			(Setting.plugin_redmine_wktime['wktime_enable_expense_module'].blank? ||
			Setting.plugin_redmine_wktime['wktime_enable_expense_module'].to_i == 0) &&
			(Setting.plugin_redmine_wktime['wktime_enable_attendance_module'].blank? ||
			Setting.plugin_redmine_wktime['wktime_enable_attendance_module'].to_i == 0) &&
			(Setting.plugin_redmine_wktime['wktime_enable_shift'].blank? ||
			Setting.plugin_redmine_wktime['wktime_enable_shift'].to_i == 0) &&
			(Setting.plugin_redmine_wktime['wktime_enable_payroll_module'].blank? ||
			Setting.plugin_redmine_wktime['wktime_enable_payroll_module'].to_i == 0) &&
			(Setting.plugin_redmine_wktime['wktime_enable_survey_module'].blank? ||
			Setting.plugin_redmine_wktime['wktime_enable_survey_module'].to_i == 0) &&
			(Setting.plugin_redmine_wktime['wktime_enable_billing_module'].blank? ||
			Setting.plugin_redmine_wktime['wktime_enable_billing_module'].to_i == 0) &&
			(Setting.plugin_redmine_wktime['wktime_enable_accounting_module'].blank? ||
			Setting.plugin_redmine_wktime['wktime_enable_accounting_module'].to_i == 0) &&
			(Setting.plugin_redmine_wktime['wktime_enable_crm_module'].blank? ||
			Setting.plugin_redmine_wktime['wktime_enable_crm_module'].to_i == 0) &&
			(Setting.plugin_redmine_wktime['wktime_enable_purchase_module'].blank? ||
			Setting.plugin_redmine_wktime['wktime_enable_purchase_module'].to_i == 0) &&
			(Setting.plugin_redmine_wktime['wktime_enable_inventory_module'].blank? ||
			Setting.plugin_redmine_wktime['wktime_enable_inventory_module'].to_i == 0) &&
			(Setting.plugin_redmine_wktime['wktime_enable_report_module'].blank? ||
			Setting.plugin_redmine_wktime['wktime_enable_report_module'].to_i == 0 ) ) ||
			((Setting.plugin_redmine_wktime['wktime_enable_dashboards_module'].blank? ||
			Setting.plugin_redmine_wktime['wktime_enable_dashboards_module'].to_i == 0))
	end
	
	def getDatesSql(from, intervalVal, intervalType)
		sqlStr = "(select " + getAddMonthDateStr(from,intervalVal,intervalType) + " selected_date from " +
			"(select 0 i union select 1 union select 2 union select 3 union select 4 union select 5 union select 6 union select 7 union select 8 union select 9) t0,
			 (select 0 i union select 1 union select 2 union select 3 union select 4 union select 5 union select 6 union select 7 union select 8 union select 9) t1,
			 (select 0 i union select 1 union select 2 union select 3 union select 4 union select 5 union select 6 union select 7 union select 8 union select 9) t2,
			 (select 0 i union select 1 union select 2 union select 3 union select 4 union select 5 union select 6 union select 7 union select 8 union select 9) t3,
			 (select 0 i union select 1 union select 2 union select 3 union select 4 union select 5 union select 6 union select 7 union select 8 union select 9)t4"
		if intervalType == 'month'
			sqlStr = sqlStr + " where #{getIntervalFormula(intervalVal)}<24000" 
		end
		sqlStr = sqlStr + " )v"
	
	end
	
	def getAddMonthDateStr(dtfield,intervalVal,intervalType)
		interval = getIntervalFormula(intervalVal)
		if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'			 
			dateSqlStr = "date('#{dtfield}') + interval '1 month' * "	+ interval.to_s
		elsif ActiveRecord::Base.connection.adapter_name == 'SQLite'			 
			dateSqlStr = "date('#{dtfield}' , '+' || " + "(#{interval.to_s})" + " || ' months')"
		elsif ActiveRecord::Base.connection.adapter_name == 'SQLServer'		
			dateSqlStr = "DateAdd(m, " + interval.to_s + ",'#{dtfield}')"
		else
			dateSqlStr = "adddate('#{dtfield}', INTERVAL " + interval.to_s + " MONTH )"
		end		
		dateSqlStr
	end
	
	def getIntervalFormula(intervalVal)
		" (t4.i*#{intervalVal}*10000 + t3.i*#{intervalVal}*1000 + t2.i*#{intervalVal}*100 + t1.i*#{intervalVal}*10 + t0.i*#{intervalVal}) "
	end
	
	def isLocked(startdate)
		isLocked = false
		lock = WkTeLock.order(id: :desc)	
		if !lock.blank? && lock.size > 0		
			startdate = startdate.to_s.to_date
			isLocked = startdate <= lock[0].lock_date.to_date			
		end
		isLocked
	end
	
	def concatColumnsSql(columnsArr, aliasName, joinChar)
		joinChar = ' ' if joinChar.blank?
		if ActiveRecord::Base.connection.adapter_name == 'SQLServer'	
			concatSql = " #{columnsArr.join(" + '#{joinChar}' + ")} "	
		elsif ActiveRecord::Base.connection.adapter_name == 'SQLite'
			concatSql = " #{columnsArr.join(" || '#{joinChar}' || ")} "
		else
			concatSql = " concat( #{columnsArr.join(" , '#{joinChar}' , ")}) "
		end
		concatSql = concatSql + " as #{aliasName} " unless aliasName.blank?
		concatSql
	end
		
	def showPurchase
		(!Setting.plugin_redmine_wktime['wktime_enable_purchase_module'].blank? &&
			Setting.plugin_redmine_wktime['wktime_enable_purchase_module'].to_i == 1 ) && (validateERPPermission("B_PUR_PRVLG") || validateERPPermission("A_PUR_PRVLG"))
	end
	
	def showInventory
		(!Setting.plugin_redmine_wktime['wktime_enable_inventory_module'].blank? &&
			Setting.plugin_redmine_wktime['wktime_enable_inventory_module'].to_i == 1 ) && validateERPPermission("V_INV") 
	end
	
	def generic_options_for_select(model, sqlCond, orderBySql, displayCol, valueCol, selectedVal, needBlank)
		ddArray = Array.new
		if sqlCond.blank? || orderBySql.blank?
			if sqlCond.blank? && orderBySql.blank?
				ddValues = model.all
			else
				if sqlCond.blank?
					ddValues = model.order("#{orderBySql}")
				else	
					ddValues = model.where("#{sqlCond}")
				end
			end
		else
			ddValues = model.where("#{sqlCond}").order("#{orderBySql}")
		end
		unless ddValues.blank?
			#ddArray = ddValues.collect {|t| [t["#{displayCol}"], t["#{valueCol}"]] 
			ddValues.each do | entry |
				ddArray << [entry["#{displayCol}"], entry["#{valueCol}"]]
				selectedVal = entry.id if model == WkLocation && selectedVal.nil? && entry.is_default?
			end
		end
		
		if model == WkLocation
			ddArray = ddArray.unshift([" ","0"]) if needBlank
		else
			ddArray = ddArray.unshift(["",""]) if needBlank
		end
		options_for_select(ddArray, :selected => selectedVal)
	end
	
	def hasSettingPerm
		ret = false
		ret = (User.current.admin) || validateERPPermission("ADM_ERP") || validateERPPermission('A_TE_PRVLG') || (validateERPPermission("V_INV") && validateERPPermission("D_INV")) || validateERPPermission("A_ACC_PRVLG") || validateERPPermission("A_CRM_PRVLG") || validateERPPermission("A_PUR_PRVLG") || validateERPPermission("M_BILL")
		ret
	end
	
	def erpModules
		erpmineModules = {l(:label_dashboards) => 'Dashboards',
						  l(:label_wktime) => 'Time',
						  l(:label_wkexpense) => 'Expense',
						  l(:report_attendance) => 'Attendance',
						  l(:label_payroll) => 'Payroll',
						  l(:label_shift_scheduling) => 'Shift Scheduling',
						  l(:label_wk_billing) => 'Billing',
						  l(:label_accounting) => 'Accounting',
						  l(:label_crm) => 'CRM',
						  l(:label_txn_purchase) => 'Purchase',
						  l(:label_inventory) => 'Inventory',
						  l(:label_survey) => 'Survey',
						  l(:label_report) => 'Report'
					 }
		erpmineModules
	end

	def validateERPPermission(permission)
		permissionArr = Array.new
		user = User.current
		user.groups.each do |group|
			groupPermission = WkGroupPermission.where(:group_id => group.id)
			groupPermission.each do |grp|
				unless grp.permission.blank?
					shortname = grp.permission.short_name
					permissionArr << shortname
				end
		  end
		end
		return permissionArr.include? permission
	end
	
	def showShiftScheduling
		!Setting.plugin_redmine_wktime['wktime_enable_shift scheduling_module'].blank? && Setting.plugin_redmine_wktime['wktime_enable_shift scheduling_module'].to_i == 1
	end
	
	def options_for_number_select(startWith, endOn, incrementBy, selectedValue)
		numArr = Array.new
		num = startWith
		until endOn < num && incrementBy > 0
			if num < 10
				numArr << ['0' + num.to_s,num]
			else
				numArr << [num,num]
			end
			num = num + incrementBy
		end
		options_for_select(numArr, :selected => selectedValue )
	end
	
	def getSpentFor(spentForKey)
		spentForArr = spentForKey.split('_')
		spentForArr
	end
	
	def getDateTime(dateVal, hrVal, minVal, secVal)
		dateTimeVal = dateVal.to_datetime
		dateTimeVal = getFormatedTimeEntry(dateTimeVal)
		dateTimeVal = dateTimeVal.change(:hour => hrVal.to_i, :min => minVal.to_i, :sec => secVal.to_i)
		dateTimeVal
	end
	
	def getFormatedTimeEntry(entryDateTime)
		entryTime = nil
		if !entryDateTime.blank?
			entryLocal = entryDateTime.change(:offset => Time.current.localtime.strftime("%:z"))
			entryTime = Time.parse("#{entryLocal.to_date.to_s} #{entryLocal.utc.to_time.to_s} ").localtime
		end
		entryTime
	end
	
	def saveSpentFor(id, spentForId, spentFortype, spentId, spentType, spentDate, spentHr, spentMm, invoiceId)
		if id.blank?
			spentObj = WkSpentFor.new
		else
			spentObj = WkSpentFor.find(id.to_i)
		end
		spentObj.spent_for_id = spentForId
		spentObj.spent_for_type = spentFortype
		spentObj.spent_id = spentId
		spentObj.spent_type = spentType
		spentObj.spent_on_time = getDateTime(spentDate, spentHr, spentMm, '00')
		spentObj.invoice_item_id = invoiceId
		spentObj.save
	end
	
	def getMonthsBetween(startDate, endDate, startDay)
		startDtPeriod = getPeroid(startDate, startDay, 'M')
		endDtPeriod = getPeroid(endDate, startDay, 'M')
		if startDtPeriod[0]  == endDtPeriod[0]
			noOfMonths = (getDaysBetween(startDate, endDate)) /  (getDaysBetween(startDtPeriod[0], startDtPeriod[1]) * 1.0 )
		else			
			noOfMonths = (((getDaysBetween(startDate, startDtPeriod[1]) ) / (getDaysBetween(startDtPeriod[0], startDtPeriod[1]) * 1.0 )) + (getDaysBetween(endDtPeriod[0], endDate)/ (getDaysBetween(endDtPeriod[0], endDtPeriod[1]) * 1.0)) + (getMonthDiff((startDtPeriod[1] + 1.day) , (endDtPeriod[0] - 1.day))))
		end
		noOfMonths		
	end
	
	def getPeroid(dateVal, startDay, periodType)
		startDt = dateVal
		endDt = dateVal
		case periodType
		when 'M'
			startDt = (dateVal - (startDay -1).days).beginning_of_month + (startDay -1).days
			endDt = (dateVal - (startDay -1).days).end_of_month + (startDay -1).days
		when 'W'
			startDt = getWeekStartDt(dateVal, startDay)	
			endDt = startDt + 6.days
		end
		period = [startDt, endDt]
		period
	end
	
	# return number of months between two dates
	def getMonthDiff(from, to)
		(to.year * 12 + to.month) - (from.year * 12 + from.month)
	end
	
	# return number of days between two dates
	def getDaysBetween(from, to)
		(to.to_date - from.to_date).to_i + 1
	end
	
	# def getWeeksBetween(startDate, endDate, startDay)
		# #startDay = getPluginSetting('wktime_pay_day')
		# startDtPeriod = getPeroid(startDate, startDay, 'W')
		# endDtPeriod = getPeroid(endDate, startDay, 'W')
		# Rails.logger.info("******* startDtPeriod #{startDtPeriod} endDtPeriod #{endDtPeriod} **************************")
		# if startDtPeriod[0]  == endDtPeriod[0]
			# noOfDays = (getDaysBetween(startDate, endDate)) /  (getDaysBetween(startDtPeriod[0], startDtPeriod[1]) * 1.0 )
		# else			
			# noOfDays = ((getDaysBetween(startDate, startDtPeriod[1]) ) / (getDaysBetween(startDtPeriod[0], startDtPeriod[1]) * 1.0 )) + (getDaysBetween(endDtPeriod[0], endDate)/ (getDaysBetween(endDtPeriod[0], endDtPeriod[1]) * 1.0))
			# noOfDays = noOfDays + getNoOfPeriod((startDtPeriod[1] + 1.day) , (endDtPeriod[0] - 1.day), 'W')
		# end
		# Rails.logger.info("================= noOfDays #{noOfDays} st #{((getDaysBetween(startDate, startDtPeriod[1])) / (getDaysBetween(startDtPeriod[0], startDtPeriod[1]) * 1.0 ))}  et #{(getDaysBetween(endDtPeriod[0], endDate)/ (getDaysBetween(endDtPeriod[0], endDtPeriod[1]) * 1.0))} ===========================")
		# noOfDays		
	# end
	
	#change the date to first day of week
	def getWeekStartDt(date, startDay)	
		startOfWeek = startDay
		#Martin Dube contribution: 'start of the week' configuration
		unless date.blank?			
			#the day of calendar week (0-6, Sunday is 0)			
			dayfirst_diff = (date.wday+7) - (startOfWeek)
			date -= (dayfirst_diff%7)
		end		
		date
	end
	
	# def getNoOfPeriod(from, to, periodType)
		# case periodType
		# when 'M'
			# periodCount = getMonthDiff(from, to)
		# when 'W'
			# periodCount = getDaysBetween(from,to)/7
		# end
		# periodCount
	# end
	
	def getDuration(from, to, durationAs, totalHours, calcByHours)
	
		duration = 0
		case durationAs.upcase
		when 'H'
			duration = totalHours
		when 'D'
			duration = getDaysBetween(from, to)
		when 'BW'
			startDay = getInvWeekStartDay
			duration = getDaysBetween(from, to)/14.0 #getWeeksBetween(from,to, startDay)/2.0	
		when 'W'
			startDay = getInvWeekStartDay
			duration = getDaysBetween(from, to)/7.0 #getWeeksBetween(from,to, startDay)			
		when 'M'
			startDay = getMonthStartDay # should get from settings
			duration = getMonthsBetween(from, to, startDay)
		when 'Q'
			startDay = getMonthStartDay # should get from settings
			duration = getMonthsBetween(from, to, startDay)/3.0
		when 'SA'
			startDay = getMonthStartDay # should get from settings
			duration = getMonthsBetween(from, to, startDay)/6.0
		when 'A'
			startDay = getMonthStartDay # should get from settings
			duration = getMonthsBetween(from, to, startDay)/12.0
		end
		duration.round(4)
	end
	
	# def getMonthStartDay
		# 1
	# end
	
	def getSpentFors(userId, projectId)
		billableProjects = Array.new
		unless projectId.blank? || userId.blank?
			user = User.find(userId)
			project = Project.find(projectId)
			projBillList = project.account_projects.includes(:parent) unless project.blank?
			usrLocationId = user.wk_user.blank? ? nil : user.wk_user.location_id
			# spent_for_key = parentType.to_s + '_' + parentId.to_s
			locationBillProject = projBillList.select {|bp| bp.parent.location_id == usrLocationId}
			locationBillProject = locationBillProject.sort_by{|parent_type| parent_type}
			#billableProject = locationBillProject.detect {|billProj| billProj.parent_type == parentType && billProj.parent_id == parentId} unless entry.nil?
			billableProjects = locationBillProject.collect {|billProj| [billProj.parent.name, billProj.project_id.to_s + '|' + billProj.parent_type.to_s + '_' + billProj.parent_id.to_s]}
		end
		billableProjects
	end
	
	def getInvWeekStartDay
		startDay = Setting.plugin_redmine_wktime['wktime_generate_invoice_day']
		startDay = 0 if startDay.blank?
		startDay.to_i
	end
	
	def getMonthStartDay
		startDay = Setting.plugin_redmine_wktime['wktime_generate_invoice_month_start']
		startDay = 1 if startDay.blank?
		startDay.to_i
	end
	
	# =========== Supervisor feature code merge ==========
		
	def getDirectReportUsers(user_id)
		cond =	['parent_id = ?', user_id]
		userList = User.where(cond).order("#{User.table_name}.firstname ASC,#{User.table_name}.lastname ASC") 
		userList	
	end
  
	def getReportUsers(user_id)  
		supervisor = User.find(user_id)
		reportees = User.where("(#{User.table_name}.lft > #{supervisor.lft} AND #{User.table_name}.rgt < #{supervisor.rgt})")
		.order("#{User.table_name}.firstname ASC,#{User.table_name}.lastname ASC")
	end
  
	def isSupervisor
		directSubOrdCnt = User.where(:parent_id => User.current.id).count
		ret =  directSubOrdCnt > 0 ? true : false
	end
	
	def getProjectMembers(projId, cond)
		project = Project.find(projId)			
		members = project.members.where(cond).order("#{User.table_name}.firstname ASC,#{User.table_name}.lastname ASC") #.distinct("#{User.table_name}.id")
		members = members.to_a.uniq if !members.nil?
	end
	
	def getGroupMembersByCond(grpId,cond)
		scope=User.in_group(grpId).where(cond)
		members = scope.sort
		members
	end
	
	def getReportUserIdsStr
		userIds = nil
		userList = getReportUsers(User.current.id)
		userIds = userList.collect{|usr| usr.id }.map(&:inspect).join(', ')
		userIds
	end
	
	def getUsersProjects(user_id, includeSupProj=false)
		reportUsrs = getReportUsers(user_id)
		usrIds = ""
		sub_ord_projects = nil
		if !reportUsrs.blank?
			usrIds = reportUsrs.collect{|usr| usr.id }.map(&:inspect).join(', ')
			if includeSupProj
				usrIds = !usrIds.blank? ? (usrIds + ', ' + user_id.to_s) : user_id.to_s
			end
			sub_ord_projects = Project.find_by_sql("select distinct p.* from projects p " +
							  "inner join members m on p.id = m.project_id " +
							  "and m.user_id in (" + usrIds + ") and p.status = #{Project::STATUS_ACTIVE}" + " order by (p.name)")
		end
		sub_ord_projects
	end
	
	def isSupervisorForUser(user_id)
		ret = false
		rptUsers = getReportUsers(User.current.id)
		if !rptUsers.blank?
			userIdArr = rptUsers.collect(&:id)
			ret = userIdArr.include?(user_id)
		end
		ret
	end

	def getManageProject		
		roleIds = ""
		#isManager = false
		roles = User.current.memberships.collect {|m| m.roles}.flatten.uniq
		roles.any? {|role|
			tmpIsManager = role.allowed_to?(:edit_time_entries) && role.allowed_to?(:view_time_entries)
			if tmpIsManager
				#isManager = tmpIsManager
				roleIds = roleIds.blank? ? role.id.to_s : roleIds + ", " + role.id.to_s
			end
		}
		members = nil, projectIdArr = Array.new
		if !roleIds.blank?
			members = Member.joins(:member_roles).where("#{Member.table_name}.user_id = #{User.current.id} and #{MemberRole.table_name}.role_id in (#{roleIds})")
			projectIdArr = members.collect{|i| i.project_id} if !members.blank?
		end
		projectIdArr
	end	
	
	def isSupervisorApproval
		(!Setting.plugin_redmine_wktime['ftte_supervisor_based_approval'].blank? && Setting.plugin_redmine_wktime['ftte_supervisor_based_approval'].to_i == 1)
	end
	
	def canSupervisorEdit
		#(!Setting.plugin_redmine_wktime.blank? && !Setting.plugin_redmine_wktime['ftte_edit_time_log'].blank? && Setting.plugin_redmine_wktime['ftte_edit_time_log'].to_i == 1)
		# Move the canSupervisorEdit and overrideSpentTime under one isSupervisorApproval settings
		isSupervisorApproval
	end
	
	def overrideSpentTime
		# (!Setting.plugin_redmine_wktime['ftte_override_spent_time_report'].blank? && Setting.plugin_redmine_wktime['ftte_override_spent_time_report'].to_i == 1)
		# Move the canSupervisorEdit and overrideSpentTime under one isSupervisorApproval settings
		isSupervisorApproval
	end
	
	# Get the projet members based on their reporters
	def getSupervisorMembers(projectId, page=nil)
		members = Array.new
		userIds = nil	
		userList = getReportUsers(User.current.id)
		userIds = userList.collect{|usr| usr.id }.map(&:inspect).join(', ')
		#if (!context[:params][:includeSupr].blank? && context[:params][:includeSupr])
		userIds = !userIds.blank? ? (userIds + ', ' + User.current.id.to_s) : User.current.id.to_s
		#end
		cond = "1=1"
		if ((!page.blank? && !userList.blank? && userList.size > 0) || !validateERPPermission('A_TE_PRVLG'))
			cond =	"#{User.table_name}.id in(#{userIds})"
		end
		if !projectId.blank?					
			members = getProjectMembers(projectId,cond)
		end
		members
	end
	
	def getSuperViewPermission			
		userList = getReportUsers(User.current.id)
		userIds = userList.collect{|usr| usr.id }.map(&:inspect).join(', ')
		if userIds.blank?
			userIds = User.current.id
		end
		cond =	"user_id in(#{userIds})"
		projMember = Member.where(cond)
		showMenu = projMember.size > 0
		showMenu
	end
	
	# ============ End of supervisor code merge =========
	
	def showTime
		!Setting.plugin_redmine_wktime['wktime_enable_time_module'].blank? &&
			Setting.plugin_redmine_wktime['wktime_enable_time_module'].to_i == 1
  	end
	
	def show_plugin_name
		show_erpmine = 'false'
		erpModules.values.each do | erpmodule |
			perm_setting = WkPermission.where(:modules => erpmodule)
			erpmodule = erpmodule.downcase
			unless perm_setting.first.blank?
				perm_setting.each do | permission |
					show_erpmine = 'true' if Setting.plugin_redmine_wktime["wktime_enable_#{erpmodule}_module"].to_i == 1 && validateERPPermission(permission.short_name)
				end
			else
				show_erpmine = 'true' if Setting.plugin_redmine_wktime["wktime_enable_#{erpmodule}_module"].to_i == 1
			end
		end
		show_erpmine
	end

	def set_module
		redirect = { :action => 'index'}
		erpModules.values.each do | erpmodule |
			case erpmodule
				when "Time"
					if showTime && checkViewPermission
						redirect[:controller] = 'wktime' 
						return redirect
					end
				when "Expense"
					if showExpense && checkViewPermission
						redirect[:controller] = 'wkexpense'
						return redirect
					end
				when "Attendance"
					if showAttendance
						redirect[:controller] = 'wkattendance'
						return redirect
					end
				when "Payroll"
					if showPayroll
						redirect[:controller] = 'wkpayroll'
						return redirect
					end
				when "Shift Scheduling"
					if showShiftScheduling
						redirect[:controller] = 'wkscheduling'
						return redirect
					end
				when "CRM"
					if showCRMModule && (validateERPPermission("B_CRM_PRVLG") || validateERPPermission("A_CRM_PRVLG"))
						redirect[:controller] = 'wklead'
						return redirect
					end
				when "Billing"
					if showBilling && validateERPPermission("M_BILL")
						redirect[:controller] = 'wkinvoice'
						return redirect
					end
				when "Accounting"
					if showAccounting && (validateERPPermission("A_ACC_PRVLG") || validateERPPermission("B_ACC_PRVLG"))
						redirect[:controller] = 'wkgltransaction'
						return redirect
					end
				when "Purchase"
					if showPurchase && validateERPPermission("B_PUR_PRVLG")
						redirect[:controller] = 'wkrfq'
						return redirect
					end
				when "Inventory"
					if showInventory && (validateERPPermission("V_INV") || validateERPPermission("D_INV"))
						redirect[:controller] = 'wkproduct'
						return redirect
					end
				when "Survey"
					if showSurvey
						redirect[:controller] = 'wksurvey'
						return redirect	
					end
				when "Report"
					if showReports && validateERPPermission("V_REPORT")
						redirect[:controller] = 'wkreport'
						return redirect
					end
			end
		end
	end

	def set_attendance_module
		redirect = {:action => 'index'}
		if showPayroll
			redirect[:controller] = 'wkpayroll'
		elsif showShiftScheduling
			redirect[:controller] = 'wkscheduling'
		elsif showSurvey
			redirect[:controller] = 'wksurvey'
			redirect[:action] = 'user_survey'
		else
			redirect = Hash.new
		end
		redirect
	end
end