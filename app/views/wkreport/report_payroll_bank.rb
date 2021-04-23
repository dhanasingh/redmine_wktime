module ReportPayrollBank
  include WkreportHelper

  def calcReportData(user_id, group_id, projId, from, to)
    to = (from >> 1) - 1
    userSqlStr = getUserQueryStr(group_id, user_id, from)
    @userlist = User.find_by_sql(userSqlStr)
    queryStr = getQueryStr + 			
        "left join groups_users gu on (gu.user_id = u.id and gu.group_id = #{group_id}) " +
        "where u.type = 'User' and component_type != 'c' and (wu.termination_date >= '#{from}' or (u.status = #{User::STATUS_ACTIVE} and wu.termination_date is null))"
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
      @rowval["#{user.id}"]["Account Number"] = @userdetails["#{user.id}"]["Account Number"]
      @rowval["#{user.id}"]["Net"] = syscurrency.to_s + ((@totalhash["#{user.id}"]["gross"]).to_f - (@totalhash["#{user.id}"]["deduction"]).to_f + (@totalhash["#{user.id}"]["reimbursement"]).to_f).to_s
      count = count + 1
    end
    data = {headerarr: @headerarr, rowval: @rowval, usercol: usercol, syscurrency: syscurrency, salary_data: @salary_data, compTotalHash: compTotalHash}
  end
end