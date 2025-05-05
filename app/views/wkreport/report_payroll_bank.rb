module ReportPayrollBank
  include WkreportHelper

  def calcReportData(user_id, group_id, projId, from, to)
    to = (from >> 1) - 1
    userSqlStr = getUserQueryStr(group_id, user_id, from)
    @userlist = User.find_by_sql(userSqlStr)
    queryStr = getQueryStr +
        "left join groups_users gu on (gu.user_id = u.id and gu.group_id = #{group_id}) "+ 
        "where u.type = 'User' and component_type != 'c' and (wu.termination_date >= '#{from}' or (u.status = #{User::STATUS_ACTIVE} and wu.termination_date is null))" + get_comp_cond('u')
    if group_id.to_i > 0 && user_id.to_i < 1
      queryStr = queryStr + " and gu.group_id is not null"
    elsif user_id.to_i > 0
      queryStr = queryStr + " and s.user_id = #{user_id}"
    end

    queryStr = queryStr + " and s.salary_date  between '#{from}' and '#{to}' "

    if !(validateERPPermission('A_TE_PRVLG') || User.current.admin?)
      queryStr = queryStr + " and u.id = #{User.current.id} "
    end

    queryStr = queryStr + " order by s.user_id"
    @salary_data = WkSalary.find_by_sql(queryStr)
    usercol = ["#", "Name", "Routing Number", "Account Number"]
    totalcol = ["Net"]
    @headerarr = usercol + totalcol
    @salaryval = Hash.new{|hsh,key| hsh[key] = {} }
    @totalhash = Hash.new{|hsh,key| hsh[key] = {} }
    compTotalHash = Hash.new
    last_id = 0
    totgross = 0
    totdeduction = 0
    reimbursement = 0
    last_salary_date = 	nil
    syscurrency = Setting.plugin_redmine_wktime['wktime_currency']
    @salary_data.each do |entry|
      @salaryval["#{entry.user_id}"].store "#{entry.component_name}", "#{entry.amount}"
      if entry.user_id != last_id || entry.salary_date.to_date != last_salary_date
        totgross = 0
        totdeduction = 0
        reimbursement = 0
        last_id = entry.user_id
        last_salary_date = entry.salary_date.to_date
      end
      if compTotalHash[entry.component_name].blank?
        compTotalHash[entry.component_name] = entry.amount
      else
        compTotalHash[entry.component_name] = compTotalHash[entry.component_name] + entry.amount
      end
      if entry.component_type == 'b' || entry.component_type == 'a'
        totgross = totgross + entry.amount
        compTotalHash['Gross'] = entry.amount + (compTotalHash['Gross'].blank? ? 0 : compTotalHash['Gross'])
      end
      if entry.component_type == 'd'
        totdeduction = totdeduction + entry.amount
        compTotalHash['Deduction'] = entry.amount + (compTotalHash['Deduction'].blank? ? 0 : compTotalHash['Deduction'])
      end
      if entry.component_type == 'r'
        reimbursement = reimbursement + entry.amount
        compTotalHash['Reimbursements'] = entry.amount + (compTotalHash['Reimbursements'].blank? ? 0 : compTotalHash['Reimbursements'])
      end
      @totalhash["#{entry.user_id}"].store "gross", "#{totgross}"
      @totalhash["#{entry.user_id}"].store "deduction", "#{totdeduction}"
      @totalhash["#{entry.user_id}"].store "reimbursement", "#{reimbursement}"
    end
    compTotalHash['Net'] = (compTotalHash['Gross'].blank? ? 0 : compTotalHash['Gross'])  - (compTotalHash['Deduction'].blank? ? 0 : compTotalHash['Deduction']) + (compTotalHash['Reimbursements'].blank? ? 0 : compTotalHash['Reimbursements'])
    @rowval = Hash.new{|hsh,key| hsh[key] = {} }
    @userdetails = Hash.new{|hsh,key| hsh[key] = {} }
    count = 1

    @userlist.each do |user|
      @userdetails["#{user.id}"].store "#", "#{count}"
      @userdetails["#{user.id}"].store "Name", "#{user.firstname + " " + user.lastname }"
      @userdetails["#{user.id}"].store "Routing Number", "#{user.bank_code}"
      @userdetails["#{user.id}"].store "Account Number", "#{user.account_number}"
      @headerarr.each do |entry|
        @rowval["#{user.id}"].store "#{entry}", "#{@salaryval["#{user.id}"]["#{entry}"]}"
      end

      @rowval["#{user.id}"]["#"] = @userdetails["#{user.id}"]["#"]
      @rowval["#{user.id}"]["Name"] = @userdetails["#{user.id}"]["Name"]
      @rowval["#{user.id}"]["Routing Number"] = @userdetails["#{user.id}"]["Routing Number"]
      @rowval["#{user.id}"]["Account Number"] =decrypt_values(@userdetails["#{user.id}"]["Account Number"])
      @rowval["#{user.id}"]["Net"] = syscurrency.to_s + ((@totalhash["#{user.id}"]["gross"]).to_f - (@totalhash["#{user.id}"]["deduction"]).to_f + (@totalhash["#{user.id}"]["reimbursement"]).to_f).to_s
      count = count + 1
    end
    period = @salary_data&.first.blank? ? from :  @salary_data&.first&.salary_date
    data = {headerarr: @headerarr, rowval: @rowval, usercol: usercol, syscurrency: syscurrency, salary_data: @salary_data, compTotalHash: compTotalHash, period: period}
  end

  def getExportData(user_id, group_id, projId, from, to)
    rptData = calcReportData(user_id, group_id, projId, from, to)
    headers = {}
    data = []
    total = {}
    rptData[:headerarr].each{|ele| headers[ele] = ele}
    rptData[:rowval].each do |key, value|
      data << value.to_h
    end
    rptData[:headerarr].each_with_index{|ele, index| total[ele] = index == 3 ? l(:label_total) : (rptData[:compTotalHash][ele] && (rptData[:syscurrency].to_s +  rptData[:compTotalHash][ele].to_s)) }
    data << total
    return {data: data, headers: headers, period: rptData[:period]}
  end

  def pdf_export(data)
		pdf = ITCPDF.new(current_language)
		pdf.add_page
		row_Height = 8
		page_width    = pdf.get_page_width
		left_margin   = pdf.get_original_margins['left']
		right_margin  = pdf.get_original_margins['right']
		table_width = page_width - right_margin - left_margin
		width = table_width/data[:headers].length
		pdf.ln
		pdf.SetFontStyle('B', 10)
		pdf.RDMMultiCell(table_width, row_Height, getMainLocation, 0, 'C')
		pdf.RDMMultiCell(table_width, row_Height, l(:report_payroll_bank), 0, 'C')
		pdf.RDMMultiCell(table_width, row_Height, l(:label_wages_period) + ':'+ data[:period].to_s, 0, 'C')
    logo =data[:logo]
		if logo.present?
			pdf.Image(logo.diskfile.to_s, page_width-50, 15, 30, 25)
		end
		pdf.ln(10)
		pdf.SetFontStyle('B', 9)
		pdf.set_fill_color(230, 230, 230)
		data[:headers].each{ |key, value| pdf.RDMCell(width, row_Height, value.to_s, 1, 0, 'C', 1) }
		pdf.ln
		pdf.set_fill_color(255, 255, 255)

		pdf.SetFontStyle('', 8)
		data[:data].each do |entry|
      if((data[:data]).last == entry)
        pdf.SetFontStyle('B',9)
      end
			entry.each{ |key, value| pdf.RDMCell(width, row_Height, value.to_s, 1, 0, 'C', 0) }
		  pdf.ln
		end
		pdf.Output
	end
end