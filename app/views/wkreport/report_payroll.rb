module ReportPayroll
  include WkreportHelper

  def calcReportData(user_id, group_id, projId, from, to)
    to = (from >> 1) - 1
    userSqlStr = getUserQueryStr(group_id, user_id, from)
    @userlist = User.find_by_sql(userSqlStr)
    queryStr = getQueryStr + 			
        "left join groups_users gu on (gu.user_id = u.id and gu.group_id = #{group_id}) " +
        "where u.type = 'User' and component_type != 'c'  and (wu.termination_date >= '#{from}' or (u.status = #{User::STATUS_ACTIVE} and wu.termination_date is null))"
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
    data = {headerarr: @headerarr, rowval: @rowval, usercol: usercol, salary_data: @salary_data, compTotalHash: compTotalHash}
  end
end