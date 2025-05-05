module ReportUserUtilization
    include WkreportHelper

    def calcReportData(user_id, group_id, projectId, fromDate, toDate)
        betwn_mnth_count = getInBtwMonthsArr(fromDate, toDate)
        if betwn_mnth_count.length > 12
            from = Date.civil(toDate.year,toDate.month, 1) - 11.month
            to = Date.civil((toDate + 1.month).year,(toDate + 1.month).month, 1) - 1
        else
            from = Date.civil(fromDate.year,fromDate.month, 1)
            to = Date.civil((toDate + 1.month).year,(toDate + 1.month).month, 1) - 1
        end
        userSqlStr = getUserQueryStr(group_id, user_id, from)
        user_list = User.find_by_sql(userSqlStr)
        time_entries = getTimeEntriesQuery(group_id, user_id, from, to)
        inBtwMonths = getInBtwMonthsArr(from, to)
        user_data = Hash.new
        user_list.each do |user|
            inBtwMonths.each do |monthVal|
                month_year = (monthVal.first).to_s + ","  + (monthVal.last).to_s
                key = user.id.to_s
                user_data[key] = Hash.new if user_data[key].blank?
                user_data[key][month_year]= {:bill_hrs => nil, :non_bill_hrs => nil}
            end
        end

        time_entries.each do |teDetails|
            key = teDetails.user_id.to_s
            (user_data[key] || {}).each do |hour|
                month_year = hour.first.to_s
                billable = ActiveModel::Type::Boolean.new.cast(teDetails.is_billable) ? :bill_hrs : :non_bill_hrs
                if month_year == (teDetails.tyear).to_s + "," + (teDetails.tmonth).to_s
                    user_data[key][month_year][billable] = teDetails.total
                end
            end
        end
        overallavg = getAverage(user_list, user_data, inBtwMonths)
        userReport = {users: user_list, data: user_data, periods: inBtwMonths, average: overallavg, from: from.strftime("%d-%b-%Y"), to: to.strftime("%d-%b-%Y"), location: getMainLocation, address: getAddress, mnths: I18n.t("date.abbr_month_names")}
    end

    def getTimeEntriesQuery(group_id, user_id, from, to)
        timeEntriesSqlStr = "SELECT TE.user_id, SUM(hours) AS total, CASE WHEN is_billable IS NULL THEN #{booleanFormat(false)} ELSE is_billable END AS is_billable, tyear, tmonth
            FROM time_entries AS TE
            LEFT JOIN wk_projects AS WP ON WP.project_id = TE.project_id "+ get_comp_cond('WP')+"
        LEFT JOIN groups_users AS GU ON (GU.user_id = TE.user_id AND GU.group_id =  #{group_id})
            WHERE (spent_on BETWEEN '#{from}' AND '#{to}') "+ get_comp_cond('TE')+""

        if group_id.to_i > 0 && user_id.to_i < 1
        timeEntriesSqlStr = timeEntriesSqlStr + " AND GU.group_id is not null"
        elsif user_id.to_i > 0
        timeEntriesSqlStr = timeEntriesSqlStr + " AND TE.user_id = #{user_id}"
        end

        if !(validateERPPermission('A_TE_PRVLG') || User.current.admin?)
        timeEntriesSqlStr = timeEntriesSqlStr + " AND TE.user_id = #{User.current.id} "
        end

        timeEntriesSqlStr = timeEntriesSqlStr + " GROUP BY TE.user_id, CASE WHEN is_billable IS NULL THEN #{booleanFormat(false)} ELSE is_billable END, tyear, tmonth
            ORDER BY user_id, tyear, tmonth"
        TimeEntry.find_by_sql(timeEntriesSqlStr)
    end

    def getAverage(user_list, user_data, inBtwMonths)
        average = Hash.new
        total_percentage = Hash.new
        user_list.each do |user|
            key = user.id.to_s
            user_data[key].each do |u_detail|
                total_hours = u_detail.last[:bill_hrs].to_f + u_detail.last[:non_bill_hrs].to_f
                percentage = (total_hours > 0) ? ((u_detail.last[:bill_hrs].to_f/total_hours)*100).round(2) : 0.to_f
                month_val = u_detail.first.to_s
                total_percentage[month_val] = (total_percentage[month_val].to_f + percentage)
                total_percentage[key] = (total_percentage[key].to_f + percentage)
            end

        end
        overall_avg = 0
        inBtwMonths.each do |monthVal|
            user_count = user_list.length
            month_year = (monthVal.first).to_s + ","  + (monthVal.last).to_s
            avg = (user_count > 0) ? (total_percentage[month_year].to_f/user_count.to_f).round(2) : 0
            overall_avg += avg.to_f
        end
        total_avg = inBtwMonths.length.blank? ? 0 : (overall_avg/inBtwMonths.length.to_f).round(2)
        average = {total_percentage: total_percentage,  total_avg: total_avg}
    end

    def getExportData(user_id, group_id, projectId, fromDate, toDate)
        data = {headers: {}, data: []}
        details = calcReportData(user_id, group_id, projectId, fromDate, toDate)
        data[:headers].store('name',  l(:field_user))
        details[:periods].each do |monthVal|
            data[:headers].store(monthVal, monthVal[0].to_s+' '+I18n.t("date.abbr_month_names")[monthVal[1]].to_s)
        end
        data[:headers].store('avg',  l(:label_average))
        total_percentage = Hash.new
        details[:users].each do |user|
            key = user.id.to_s
            val = {}
            val.store(user.id, user.firstname)
            details[:data][key].each do |keys, u_detail|
                total_hours = u_detail[:bill_hrs].to_f + u_detail[:non_bill_hrs].to_f
                percentage = (total_hours > 0) ? ((u_detail[:bill_hrs].to_f/total_hours)*100).round(2) : 0.to_f
                month_val = keys.to_s
                total_percentage[month_val] = (total_percentage[month_val].to_f + percentage)
                total_percentage[key] = (total_percentage[key].to_f + percentage)
                val.store(month_val, percentage.to_s + "%")
            end
            @month_count = details[:periods].length
            mnth_avg = (total_percentage[key]/@month_count).round(2).to_s
            val.store('mnth_avg', mnth_avg.to_s + "%")
            data[:data] << val
        end
        avg = {}
        overall_avg = 0
        avg.store('avg', l(:label_average))
        details[:periods].each do |monthVal|
            user_count = details[:users].length
            month_year = (monthVal.first).to_s + ","  + (monthVal.last).to_s
            usrAvg = ((user_count > 0) ? (total_percentage[month_year].to_f/user_count.to_f).round(2) : 0).to_s + "%"
            avg.store(month_year, usrAvg)
            overall_avg += usrAvg.to_f
        end
        total_avg = (@month_count.blank? ? 0 : (overall_avg/@month_count.to_f).round(2)).to_s + "%"
        avg.store('total_avg', total_avg)
        data[:data] << avg
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
		pdf.RDMMultiCell(table_width, 5, l(:report_user_utilization), 0, 'C')
		pdf.RDMMultiCell(table_width, 5, data[:from].to_s+' '+l(:label_date_to)+' '+data[:to].to_s, 0, 'C')
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
                pdf.SetFontStyle('B', 9) if key == 'avg'
                pdf.RDMCell(width, row_Height, value.to_s, 1, 0, 'C', 0)
            }
        pdf.ln
        end
        pdf.Output
    end
end