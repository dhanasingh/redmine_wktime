module ReportPayroll
  include WkreportHelper

  def calcReportData(user_id, group_id, projId, from, to)
    to = (from >> 1) - 1
    userSqlStr = getUserQueryStr(group_id, user_id, from)
    @userlist = User.find_by_sql(userSqlStr)
    queryStr = getQueryStr + 			
        "left join groups_users gu on (gu.user_id = u.id and gu.group_id = #{group_id}) " +
        "where u.type = 'User' and component_type != 'c'  and (wu.termination_date >= '#{from}' or (u.status = #{User::STATUS_ACTIVE} and wu.termination_date is null))" + get_comp_cond('u')
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
    usercol = ["Id", "Name", "Gender", "Designation"]
    basiccol = Array.new
    allowancecol = Array.new
    deductioncol = Array.new
    allComponents = WkSalaryComponents.all
    allComponents.each do |entry|
      if entry.component_type == 'b'
        basiccol << entry.name
      end
      if entry.component_type == 'a'
        allowancecol << entry.name
      end
      if entry.component_type == 'd'
        deductioncol << entry.name
      end
    end
    totalcol = ["Gross", "Deduction", "Net", "Signature", "Total Unpaid"]
    @headerarr = usercol + basiccol + allowancecol + deductioncol + totalcol
    @salaryval = Hash.new{|hsh,key| hsh[key] = {} }
    @totalhash = Hash.new{|hsh,key| hsh[key] = {} }
    compTotalHash = Hash.new
    last_id = 0
    totgross = 0 
    totdeduction = 0
    last_salary_date = 	nil
    @salary_data.each do |entry|	
      @salaryval["#{entry.user_id}"].store "#{entry.component_name}", "#{entry.amount}"	
      if entry.user_id != last_id || entry.salary_date.to_date != last_salary_date
        totgross = 0
        totdeduction = 0
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
      @totalhash["#{entry.user_id}"].store "gross", "#{totgross}" 
      @totalhash["#{entry.user_id}"].store "deduction", "#{totdeduction}"
    end

    compTotalHash['Net'] = (compTotalHash['Gross'].blank? ? 0 : compTotalHash['Gross'])  - (compTotalHash['Deduction'].blank? ? 0 : compTotalHash['Deduction'])
    @rowval = Hash.new{|hsh,key| hsh[key] = {} }
    @userdetails = Hash.new{|hsh,key| hsh[key] = {} }
    @userlist.each do |user|
      @userdetails["#{user.id}"].store "Employee_Id", "#{user.employee_id}"
      @userdetails["#{user.id}"].store "Name", "#{user.firstname}"
      @userdetails["#{user.id}"].store "Gender", "#{user.gender}"
      @userdetails["#{user.id}"].store "Designation", "#{user.designation}"	
      @headerarr.each do |entry|
        @rowval["#{user.id}"].store "#{entry}", "#{@salaryval["#{user.id}"]["#{entry}"]}"
      end

      @rowval["#{user.id}"]["Id"] = @userdetails["#{user.id}"]["Employee_Id"] 
      @rowval["#{user.id}"]["Name"] = @userdetails["#{user.id}"]["Name"]
      @rowval["#{user.id}"]["Gender"] = @userdetails["#{user.id}"]["Gender"]
      @rowval["#{user.id}"]["Designation"] = @userdetails["#{user.id}"]["Designation"]
      @rowval["#{user.id}"]["Gross"] = @totalhash["#{user.id}"]["gross"]
      @rowval["#{user.id}"]["Deduction"] = @totalhash["#{user.id}"]["deduction"]
      @rowval["#{user.id}"]["Net"] = (@totalhash["#{user.id}"]["gross"]).to_f - (@totalhash["#{user.id}"]["deduction"]).to_f
    end
    period = @salary_data&.first.blank? ? from :  @salary_data&.first&.salary_date
    data = {headerarr: @headerarr, rowval: @rowval, usercol: usercol, salary_data: @salary_data, compTotalHash: compTotalHash, period: period}
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
		rptData[:headerarr].each_with_index{|ele, index| total[ele] = index == 3 ? l(:label_total) : rptData[:compTotalHash][ele]}
    data << total
		return {data: data, headers: headers, period: rptData[:period]}
	end  

	def pdf_export(data)
		pdf = ITCPDF.new(current_language, "L")
		pdf.AddPage("L", "A1")
		row_Height = 8
		page_width    = pdf.get_page_width
		left_margin   = pdf.get_original_margins['left']
		right_margin  = pdf.get_original_margins['right']
		table_width = page_width - right_margin - left_margin
		org_width = table_width/data[:headers].length
		pdf.SetFontStyle('B', 10)
		pdf.RDMMultiCell(table_width, row_Height, l(:label_wk_form_r), 0)
		pdf.RDMMultiCell(table_width, row_Height, l(:label_register_wages), 0)
		pdf.RDMMultiCell(table_width, row_Height, l(:label_wages_rule), 0)
		pdf.RDMMultiCell(table_width, row_Height, l(:label_wk_name_address) + ':', 0)
		pdf.SetFontStyle('', 10)
		pdf.RDMCell(pdf.get_string_width(getMainLocation) + 2, row_Height, getMainLocation, 0, 1)
		pdf.RDMMultiCell(150, row_Height, getAddress, 0, 'L')
		pdf.SetFontStyle('B', 10)
		pdf.RDMMultiCell(pdf.get_string_width(l(:label_wages_period)) + 5, row_Height, l(:label_wages_period) + ':', 0, '', 0, 0)
		pdf.SetFontStyle('', 10)
		pdf.RDMMultiCell(25, row_Height, data[:period].to_s, 0)
    logo =data[:logo]
		if logo.present?
			pdf.Image(logo.diskfile.to_s, page_width-50, 15, 30, 25)
		end
		pdf.ln(10)
		pdf.SetFontStyle('B', 9)
		pdf.set_fill_color(230, 230, 230)
		data[:headers].each do |key, value|
      width = key == "Id" ? 10  : org_width
      pdf.RDMMultiCell(width, 10, value.to_s, 1, 'C', 0, 0)
    end
		pdf.ln(10)
		pdf.set_fill_color(255, 255, 255)

		pdf.SetFontStyle('', 8)
		data[:data].each do |entry|
      if((data[:data]).last == entry)
        pdf.SetFontStyle('B',9)
      end
			entry.each do |key, value|
				width = key == "Id" ? 10  : org_width
        pdf.RDMCell(width, row_Height, value.to_s, 1, 0, 'C', 0)
      end
		  pdf.ln
		end
		pdf.Output
	end
end