module ReportProjectProfitability
  include WkreportHelper

  def calcReportData(userId, groupId, projectId, from, to)
    te_from = from -1.month
    te_to = to -1.month
    betwn_mnth_count = getInBtwMonthsArr(from, to)

    if betwn_mnth_count.length > 12
      from = Date.civil(to.year,to.month, 1) - 11.month
      to = Date.civil((to + 1.month).year,(to + 1.month).month, 1) - 1
      te_from = Date.civil(te_to.year,te_to.month, 1) - 11.month
      te_to = Date.civil((te_to + 1.month).year,(te_to + 1.month).month, 1) - 1
    else
      from = Date.civil(from.year,from.month, 1)
      to = Date.civil((to + 1.month).year,(to + 1.month).month, 1) - 1
      te_from = Date.civil(te_from.year,te_from.month, 1)
      te_to = Date.civil((te_to + 1.month).year,(te_to + 1.month).month, 1) - 1
    end

    inBtwMonths = getInBtwMonthsArr(from, to)

    @salary_data = getSalaryData(from, to)

    @time_entries = getTimeEntries(te_from, te_to)

    invoice_details = getInvoiceDetails(from, to, projectId)

    @billable_projects = getBillableProjects(from, to, projectId)

    payrollAmount = Array.new
    @salary_data.each do |entry|
      payrollAmount << {:project_id => entry.project_id, :user_id => entry.user_id, :component_id => entry.sc_component_id, :amount => (entry.amount).round, :currency => entry.currency, :salary_date => entry.salary_date}
    end

    form_salaries_hash(payrollAmount, userId)

    proj_expense = Hash.new
    inBtwMonths.each do |monthVal|
    mnth_year = monthVal.last.to_i.to_s + "_" + (monthVal.first).to_s
      @time_entries.each do |te_detail|
        mnth = te_detail.spent_month+1 > 12 ? 1 : te_detail.spent_month+1
        year = te_detail.spent_month == 12 ? te_detail.spent_year+1 : te_detail.spent_year
        key = te_detail.user_id.to_s + "_" + monthVal.last.to_i.to_s + "_" + (monthVal.first).to_s+ "_" + te_detail.project_id.to_s
        inv_key = monthVal.last.to_i.to_s + "_" + (monthVal.first).to_s+ "_" + te_detail.project_id.to_s
        if mnth_year == (mnth.to_i.to_s + "_" + year.to_i.to_s) && !@payrollEntries[key].blank?
          user_salaries = @payrollEntries[key][:BT] + @payrollEntries[key][:AT]
          proj_expense[inv_key] = te_detail.user_hours.blank? ? proj_expense[inv_key].to_i :
            proj_expense[inv_key].to_i + ((te_detail.proj_hours/te_detail.user_hours)*user_salaries).round(2)
        end
      end
    end
    detail_entries = Hash.new
    col_total = Hash.new
    row_total = Hash.new
    grand_total = Hash.new
    invoice_details.each do |invoice|
      key = invoice.inv_month.to_i.to_s + "_" + invoice.inv_year.to_i.to_s + "_" + invoice.project_id.to_s
      col_key = invoice.inv_month.to_i.to_s + "_" + invoice.inv_year.to_i.to_s
      row_key = invoice.project_id.to_s
      over_head = invoice.profit_overhead_percentage.blank? ? 0 : invoice.profit_overhead_percentage
      if detail_entries[key].blank?
        detail_entries[key] = {:revenue => 0, :expense => 0, :profit => 0, :profit_percentage => 0}
      end
      if col_total[col_key].blank?
        col_total[col_key] = {:income => 0, :expense => 0}
      end
      if row_total[row_key].blank?
        row_total[row_key] = {:income => 0, :expense => 0}
      end
      if grand_total.blank?
        grand_total = {:income => 0, :expense => 0}
      end
      proj_expense[key] = proj_expense[key].blank? ? 0 : proj_expense[key]
      revenue = (invoice.invoice_amt).round(2)
      expense = ((proj_expense[key]*over_head)/100).round(2)
      org_expense = proj_expense[key] + expense
      profit = revenue - org_expense
      profit_percentage = ((profit/revenue)*100).round(2)
      profit_percentage = profit_percentage > 0 ? profit_percentage : 0
      detail_entries[key] = {:revenue => revenue.round(2), :expense => org_expense.round(2), :profit => profit.round(2), :profit_percentage => profit_percentage }
      col_total[col_key][:income] = (col_total[col_key][:income] + revenue).round(2)
      col_total[col_key][:expense] = (col_total[col_key][:expense] + org_expense).round(2)
      row_total[row_key][:income] = (row_total[row_key][:income] + revenue).round(2)
      row_total[row_key][:expense] = (row_total[row_key][:expense] + org_expense).round(2)
      grand_total[:income] = (grand_total[:income] + revenue).round(2)
      grand_total[:expense] = (grand_total[:expense] + org_expense).round(2)
    end
    totlProfitAvg = getAvgandProfit(@billable_projects, inBtwMonths, detail_entries, row_total, col_total, grand_total)
    project_profitability = { colTotal: col_total, grandTotal: grand_total, rowTotal: row_total, billProj: @billable_projects, data: detail_entries, periods: inBtwMonths, from: from.to_formatted_s(:long), to: to.to_formatted_s(:long), mnths: I18n.t("date.abbr_month_names"), currency: Setting.plugin_redmine_wktime['wktime_currency'], totlProfitAvg: totlProfitAvg }
  end

  def getSalaryData(from, to)
    queryStr = "SELECT U.id as user_id, U.firstname as firstname, U.lastname as lastname, SC.name as component_name, SC.id as sc_component_id,
      S.salary_date as salary_date, S.amount as amount, S.currency as currency, SC.component_type as component_type, M.project_id
      FROM wk_salaries AS S
      INNER JOIN wk_salary_components AS SC on S.salary_component_id=SC.id "+get_comp_cond('SC')+"
      INNER JOIN users AS U on S.user_id=U.id "+get_comp_cond('U')+"
      INNER JOIN members AS M ON M.user_id = U.id"+get_comp_cond('M')+"
      INNER JOIN wk_projects AS P ON P.project_id = M.project_id AND P.is_billable = #{booleanFormat(true)} "+get_comp_cond('P')+"
      WHERE S.salary_date  BETWEEN '#{from}' AND '#{to}' "+get_comp_cond('S')+"
      ORDER BY M.user_id, M.project_id"
    sal_data = WkSalary.find_by_sql(queryStr)
  end

  def getTimeEntries(te_from, te_to)
    te_details = "SELECT M.user_id, M.project_id, SUM(TE.hours) AS proj_hours, UT.spent_month, UT.spent_year, UT.user_hours
    FROM time_entries AS TE
    INNER JOIN(
      SELECT TE.user_id, SUM(TE.hours) AS user_hours, #{getDatePart('TE.spent_on','month','spent_month')}, #{getDatePart('TE.spent_on','year','spent_year')}
          FROM time_entries AS TE
      LEFT JOIN members AS M ON M.user_id = TE.user_id AND M.project_id = TE.project_id
      "+get_comp_cond('M')+"
      INNER JOIN wk_projects AS WP ON WP.project_id = M.project_id AND WP.is_billable = #{booleanFormat(true)}
      AND TE.spent_on BETWEEN  '#{te_from}' AND '#{te_to}' "+get_comp_cond('WP')+"
      GROUP BY TE.user_id, #{getDatePart('TE.spent_on','month')}, #{getDatePart('TE.spent_on','year')}
        ) AS UT ON UT.user_id = TE.user_id AND UT.spent_year = #{getDatePart('TE.spent_on','year')}
        AND UT.spent_month = #{getDatePart('TE.spent_on','month')} AND TE.spent_on BETWEEN  '#{te_from}' AND '#{te_to}'
    RIGHT JOIN members AS M ON M.user_id = TE.user_id AND M.project_id = TE.project_id
    "+get_comp_cond('M')+get_comp_cond('TE','WHERE')+"
    GROUP BY M.user_id, M.project_id, UT.spent_month, UT.spent_year, UT.user_hours
    HAVING SUM(TE.hours) > 0"
    time_entries = TimeEntry.find_by_sql(te_details)
  end

  def getInvoiceDetails(from, to, projectId)
    invoice_details = "	SELECT SUM(II.amount) AS invoice_amt, #{getDatePart('I.invoice_date','month','inv_month')},
    #{getDatePart('I.invoice_date','year','inv_year')}, II.project_id, WP.profit_overhead_percentage, P.name
      FROM wk_invoices AS I
      INNER JOIN wk_invoice_items AS II ON II.invoice_id = I.id "+get_comp_cond('II')+"
      INNER JOIN wk_projects AS WP ON WP.project_id = II.project_id AND WP.is_billable = #{booleanFormat(true)} "+get_comp_cond('WP')+"
      INNER JOIN projects AS P ON II.project_id = P.id "+get_comp_cond('P')+"
      WHERE I.invoice_type = 'I' AND I.invoice_date BETWEEN '#{from}' AND '#{to}'
      "+get_comp_cond('I')

      if projectId.to_i > 0
        invoice_details = invoice_details + "AND II.project_id = #{projectId} "
      end

    invoice_details	= invoice_details + " GROUP BY #{getDatePart('I.invoice_date','month')}, #{getDatePart('I.invoice_date','year')}, II.project_id, WP.profit_overhead_percentage, P.name"

    invoice_details = WkInvoice.find_by_sql(invoice_details)
  end

  def getBillableProjects(from, to, projectId)
    billable_projects = "SELECT WP.project_id, P.name
    FROM wk_projects AS WP
    INNER JOIN projects AS P ON WP.project_id = P.id "+get_comp_cond('P')+"
    INNER JOIN wk_invoice_items AS II ON II.project_id = WP.project_id "+get_comp_cond('II')+"
    INNER JOIN wk_invoices AS I ON I.id = II.invoice_id "+get_comp_cond('I')+"
    WHERE I.invoice_type = 'I' AND I.invoice_date BETWEEN '#{from}' AND '#{to}' AND is_billable = #{booleanFormat(true)} "+get_comp_cond('WP')

    if projectId.to_i > 0
    billable_projects = billable_projects + "AND WP.project_id = #{projectId} "
    end

    billable_projects = billable_projects + " GROUP BY WP.project_id, P.name "
    @billable_projects = WkProject.find_by_sql(billable_projects)
  end

  def getAvgandProfit(billable_projects, inBtwMonths, detail_entries, row_total, col_total, grand_total)
    data = {}
    profit = {}
    percentage = {}
    mnthProfit = {}
    mnthPercentage = {}
    billable_projects.each do |project|
      row_key = project.project_id.to_s
      inBtwMonths.each do |monthVal|
        key = monthVal.last.to_i.to_s + "_" + (monthVal.first).to_s + "_" + project.project_id.to_s
        if detail_entries[key].blank?
          detail_entries[key] = {:revenue => 0, :expense => 0, :profit => 0, :profit_percentage => 0}
        end
        if row_total[row_key].blank?
          row_total[row_key] = {:income => 0, :expense => 0 }
        end
        profit[row_key] = (row_total[row_key][:income] - row_total[row_key][:expense]).round(2)
        percentage[row_key] = ((profit[row_key]/row_total[row_key][:income])*100).round(2) unless row_total[row_key][:income] == 0
        percentage[row_key] = percentage[row_key].blank? ? 0 : percentage[row_key]
				percentage[row_key] = percentage[row_key] > 0 ? percentage[row_key] : 0
      end
    end

    inBtwMonths.each do |monthVal|
      col_key = monthVal.last.to_i.to_s + "_" + (monthVal.first).to_s
      if col_total[col_key].blank?
        col_total[col_key] = {:income => 0, :expense => 0 }
      end
      mnthProfit[col_key] = (col_total[col_key][:income] - col_total[col_key][:expense]).round(2)
      mnthPercentage[col_key] = ((mnthProfit[col_key]/col_total[col_key][:income])*100).round(2) unless col_total[col_key][:income] == 0
      mnthPercentage[col_key] = mnthPercentage[col_key].blank? ? 0 : mnthPercentage[col_key]
      mnthPercentage[col_key] = mnthPercentage[col_key] > 0 ? mnthPercentage[col_key] : 0
    end
    if grand_total.blank?
      grand_total = {:income => 0, :expense => 0 }
    end
    ovrAllProf = (grand_total[:income] - grand_total[:expense]).round(2)
		ovrAllAvg = ((ovrAllProf/grand_total[:income])*100).round(2) unless grand_total[:income] == 0
		ovrAllAvg = ovrAllAvg.blank? ? 0 : ovrAllAvg
		ovrAllAvg = ovrAllAvg > 0 ? ovrAllAvg : 0
    data = {detail_entries: detail_entries, row_total: row_total, ProjProfit: profit, ProjPercentage: percentage, mnthPercentage: mnthPercentage, mnthProfit: mnthProfit, ovrAllProf: ovrAllProf, ovrAllAvg: ovrAllAvg}
  end

  def getExportData(user_id, group_id, projId, from, to)
    data = {headers: {}, data: []}
    reportData = calcReportData(user_id, group_id, projId, from, to)
    entry = reportData[:totlProfitAvg]
    data[:headers] = {project:  l(:label_project)}
    reportData[:periods].each do |monthVal|
      data[:headers].store(monthVal, monthVal[0].to_s+' '+I18n.t("date.abbr_month_names")[monthVal[1]].to_s)
    end
    data[:headers].store('total',  l(:label_total))
    reportData[:billProj].each do |val|
      row_key = val.project_id.to_s
      details = {name: val.name, total: ''}
      reportData[:periods].each do |monthVal|
        details.store(monthVal, '')
      end
      data[:data] << details
      revDetails = {invoice: l(:label_revenue)}
      expDetails = {payment: l(:label_wkexpense)}
      profDetails = {balance: l(:label_profit)}
      reportData[:periods].each do |monthVal|
        key = monthVal.last.to_i.to_s + "_" + (monthVal.first).to_s + "_" + val.project_id.to_s
				entryVal = entry[:detail_entries][key]
        revDetails.store(key, reportData[:currency].to_s+' '+entryVal[:revenue].to_s)
        expDetails.store(key, reportData[:currency].to_s+' '+entryVal[:expense].to_s)
        profDetails.store(key, reportData[:currency].to_s+' '+entryVal[:profit].to_s + "(" + data[:profit_percentage].to_s + "%)")
      end
      revDetails.store('rev_total', reportData[:currency].to_s+' '+reportData[:rowTotal][row_key][:income].to_s )
      expDetails.store('exp_total', reportData[:currency].to_s+' '+reportData[:rowTotal][row_key][:expense].to_s )
      profDetails.store('prof_total', reportData[:currency].to_s+' '+entry[:ProjProfit][row_key].to_s + "(" + entry[:ProjPercentage][row_key].to_s + "%)")
      data[:data] << revDetails
      data[:data] << expDetails
      data[:data] << profDetails
    end
    total ={total:  l(:label_total) }
    reportData[:periods].each do |monthVal|
      col_key = monthVal.last.to_i.to_s + "_" + (monthVal.first).to_s
      total.store(monthVal, entry[:mnthProfit][col_key].to_s + "(" + entry[:mnthPercentage][col_key].to_s + "%)")
    end
    total.store('over_all', reportData[:currency].to_s+' '+entry[:ovrAllProf].to_s + "(" + entry[:ovrAllAvg].to_s + "%)")
    data[:data] << total
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
		logo =data[:logo]
		if logo.present?
			pdf.Image(logo.diskfile.to_s, page_width-50, 15, 30, 25)
		end
		pdf.ln(14)
    pdf.SetFontStyle('B', 13)
    pdf.RDMMultiCell(table_width, 5, data[:location], 0, 'C')
    pdf.RDMMultiCell(table_width, 5, l(:report_project_profitability), 0, 'C')
    pdf.RDMMultiCell(table_width, 5, data[:from].to_s+' '+l(:label_date_to)+' '+data[:to].to_s, 0, 'C')
		pdf.ln(8)

    pdf.SetFontStyle('B', 8)
    pdf.set_fill_color(230, 230, 230)
    data[:headers].each{ |key, value| pdf.RDMCell(width, row_Height, value.to_s, 1, 0, 'C', 1) }
    pdf.ln
    pdf.set_fill_color(255, 255, 255)

    pdf.SetFontStyle('', 8)
    data[:data].each do |entry|
      entry.each{ |key, value|
        pdf.SetFontStyle('', 8)
        pdf.SetFontStyle('B', 8) if entry == data[:data].last || key.to_s == 'name'
        border = 1 if entry == data[:data].last
        pdf.RDMCell(width, row_Height, value.to_s, border, 0, 'C', 1)
      }
      pdf.ln
    end
    pdf.Output
  end
end