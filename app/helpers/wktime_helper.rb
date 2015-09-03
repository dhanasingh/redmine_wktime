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
    export = CSV.generate(:col_sep => l(:general_csv_separator)) do |csv|
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
		weeklyHash = getWeeklyView(entries, unitLabel, true) #should send false and form unique rows
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

	weeklyHash = getWeeklyView(entries, unitLabel, true)
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
		key = entry.project.id.to_s + (entry.issue.blank? ? '' : entry.issue.id.to_s) + entry.activity.id.to_s + (unitLabel.blank? ? '' : entry.currency)
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
	
	def getWeeklyView(entries, unitLabel, sumHours = false)
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
				
				#Martin Dube contribution: 'start of the week' configuration
				#wday returns 0 - 6, 0 is sunday
				startOfWeek = getStartOfWeek
				index = (entry.spent_on.wday+7-(startOfWeek))%7
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

def getColumnValues(matrix, totals, unitLabel,rowNumberRequired, j=0)
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
						col_values[k+2] = entry.activity.name
						if !unitLabel.blank?
							col_values[k+3]= entry.currency
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
		locked = call_hook(:controller_check_locked,{ :startdate => start_day})
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
		tabs = [
				{:name => 'wktime', :partial => 'wktime/tab_content', :label => :label_wktime},
				{:name => 'wkexpense', :partial => 'wktime/tab_content', :label => :label_wkexpense}
			   ]	
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
		
		queryStr =  "select distinct u.* from projects p" +
					" inner join members m on p.id = m.project_id and p.status not in (#{Project::STATUS_CLOSED},#{Project::STATUS_ARCHIVED})"  +
					" inner join member_roles mr on m.id = mr.member_id" +
					" inner join roles r on mr.role_id = r.id and r.permissions like '%:log_time%'" +
					" inner join users u on m.user_id = u.id" +
					" left outer join wktimes w on u.id = w.user_id and w.begin_date = '" + startDate.to_s + "'" +
					" where (w.status is null or w.status = 'n')"			
		
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
			# mysql - the weekday index for date (0 = Monday, 1 = Tuesday, … 6 = Sunday)
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
				{:name => 'display', :partial => 'settings/tab_display', :label => :label_display},
				{:name => 'wktime', :partial => 'settings/tab_time', :label => :label_wktime},
				{:name => 'wkexpense', :partial => 'settings/tab_expense', :label => :label_wkexpense},
				{:name => 'approval', :partial => 'settings/tab_approval', :label => :label_wk_approval_system},
				{:name => 'publicHoliday', :partial => 'settings/tab_holidays', :label => :label_wk_public_holiday}
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
			viewMenu = call_hook(:view_wktime_menu)
			viewMenu  = viewMenu.blank? ? '' : (viewMenu.is_a?(Array) ? (viewMenu[0].blank? ? '': viewMenu[0].to_s) : viewMenu.to_s) 
			#@manger_user = (!viewMenu.blank? && to_boolean(viewMenu))	
			ret = (!viewProjects.blank? && viewProjects.size > 0) || (!loggableProjects.blank? && loggableProjects.size > 0) || isAccountUser || (!viewMenu.blank? && to_boolean(viewMenu))
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
	
	def isAccountUser
		group = nil
		isAccountUser = false
		groupusers = Array.new
		accountGrpIds = Setting.plugin_redmine_wktime['wktime_account_groups'] if !Setting.plugin_redmine_wktime['wktime_account_groups'].blank?
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
		grpUserIds = groupusers[0].collect{|user| user.id}.uniq if !groupusers.blank? && !groupusers[0].blank?
		isAccountUser = grpUserIds.include?(User.current.id)
	end
	
	def getAccountUserProjects
		Project.where(:status => "#{Project::STATUS_ACTIVE}").order('name')
	end
	
	def getAddDateStr(dtfield,noOfDays)
		if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'			 
			dateSqlStr = "date('#{dtfield}') + "	+ noOfDays.to_s
		elsif ActiveRecord::Base.connection.adapter_name == 'SQLite'			 
			dateSqlStr = "date('#{dtfield}' , '+' || " + noOfDays.to_s + " || ' days')"
		elsif ActiveRecord::Base.connection.adapter_name == 'SQLServer'		
			dateSqlStr = "DateAdd(d, " + noOfDays.to_s + ",'#{dtfield}')"
		else
			dateSqlStr = "adddate('#{dtfield}', " + noOfDays.to_s + ")"
		end		
		dateSqlStr
	end
end