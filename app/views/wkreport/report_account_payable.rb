module ReportAccountPayable
  include WkreportHelper

  def calcReportData(user_id, group_id, projId, from, to)
    from = Date.civil(from.year,from.month, 1)
    to = Date.civil((to + 1.month).year,(to + 1.month).month, 1) - 1
    inBtwMonths = getInBtwMonthsArr(from, to)
    sqlStr = "select ac.*, idt.inv_amount, pdt.pay_amount, idt.inv_currency, pdt.pay_currency, oi.prv_invoice_amount, op.prv_payment_amount,
    coalesce(a.name, CONCAT(cc.first_name,' ',cc.last_name)) as name from (select p.parent_id, p.parent_type, #{getDatePart('v.selected_date','year','year_val')}, #{getDatePart('v.selected_date','month','month_val')} from
    #{getDatesSql(from, 1, 'month', to)},
    (#{getAccountContactSql("AP-Aging")}) p
    ) ac
    left join
    (select inv.parent_id, inv.parent_type, inv.inv_month, inv.inv_year, sum(inv.amount) as inv_amount, inv.inv_currency from
      (select ii.amount, ii.currency as inv_currency, ii.invoice_id, i.invoice_date,i.parent_type, i.parent_id, i.invoice_type, #{getDatePart('invoice_date','month','inv_month')},#{getDatePart('invoice_date','year','inv_year')}
      from wk_invoice_items ii
      left join wk_invoices i on i.id = ii.invoice_id " + get_comp_cond('i') + "
      where i.invoice_date between '#{from}' and '#{to}' and i.invoice_type = 'SI' and ii.credit_invoice_id is null and ii.credit_payment_item_id is null " + get_comp_cond('ii') + ") as inv
      group by inv.parent_type, inv.parent_id, inv.inv_year, inv.inv_month,inv.inv_currency) as idt
    on(ac.parent_id=idt.parent_id and ac.parent_type=idt.parent_type and ac.month_val=idt.inv_month and ac.year_val=idt.inv_year)
    left join
    (select pay.parent_id, pay.parent_type, pay.pay_month, pay.pay_year, sum(pay.amount) as pay_amount,pay.pay_currency from
    (select ii.amount, ii.currency as pay_currency, ii.payment_id, i.payment_date,i.parent_type, i.parent_id, #{getDatePart('payment_date','month','pay_month')}, #{getDatePart('payment_date','year','pay_year')} from wk_payment_items ii
    left join wk_payments i on i.id = ii.payment_id " + get_comp_cond('i') + "
    where i.payment_date between '#{from}' and '#{to}' and ii.is_deleted = #{booleanFormat(false)} " + get_comp_cond('ii') + ") as pay
    group by pay.parent_type, pay.parent_id, pay.pay_year, pay.pay_month,pay.pay_currency) as pdt
    on(ac.parent_id=pdt.parent_id and ac.parent_type=pdt.parent_type and ac.month_val=pdt.pay_month and ac.year_val=pdt.pay_year)
    left join
    (select sum(pii.amount) prv_invoice_amount, pvi.parent_type,pvi.parent_id from wk_invoice_items pii
    left join wk_invoices pvi on pvi.id = pii.invoice_id " + get_comp_cond('pvi') + " where pvi.invoice_date < '#{from}' and pii.credit_invoice_id is null and pii.credit_payment_item_id is null " + get_comp_cond('pii') + "
    group by pvi.parent_type,pvi.parent_id) oi
    on (oi.parent_type = ac.parent_type and oi.parent_id = ac.parent_id)
    left join
    (select sum(pii.amount) prv_payment_amount, pvi.parent_type,pvi.parent_id from wk_payment_items pii
    left join wk_payments pvi on pvi.id = pii.payment_id " + get_comp_cond('pvi') + " where pvi.payment_date < '#{from}' and pii.is_deleted = #{booleanFormat(false)} " + get_comp_cond('pii') + "
    group by pvi.parent_type,pvi.parent_id) op
    on (op.parent_type = ac.parent_type and op.parent_id = ac.parent_id)
    left join wk_crm_contacts cc on (cc.id = ac.parent_id and ac.parent_type = 'WkCrmContact' " + get_comp_cond('cc') + ")
    left join wk_accounts a on (a.id = ac.parent_id and ac.parent_type = 'WkAccount' " + get_comp_cond('a') + ") "

    parentIdHash = getProjectBillers(projId)
    if !projId.blank? && projId != '0'
      sqlCond = ""
      if parentIdHash['WkAccount'].length > 0
        sqlCond = " ac.parent_type= 'WkAccount' and ac.parent_id in (#{parentIdHash['WkAccount'].join(',')})"
      end
      if parentIdHash['WkCrmContact'].length > 0
        sqlCond = sqlCond + " OR" unless sqlCond.blank?
        sqlCond = sqlCond + " (ac.parent_type= 'WkCrmContact' and ac.parent_id in (#{parentIdHash['WkCrmContact'].join(',')}))"
      end
      unless sqlCond.blank?
        sqlStr = sqlStr + " where" + sqlCond
      else
        sqlStr = sqlStr + " where ac.parent_id = 0"
      end
    end

    sqlStr = sqlStr + " order by parent_type, parent_id, year_val, month_val"
    entries = WkInvoice.find_by_sql(sqlStr)

    data = getRowData(entries)
    data_entries = {entries: entries, periods: inBtwMonths, from: from.to_formatted_s(:long), to: to.to_formatted_s(:long), mnths: I18n.t("date.abbr_month_names"), data: data}
  end

  def getRowData(entries)
    syscurrency = Setting.plugin_redmine_wktime['wktime_currency']
    data = {}
    current_balance = 0
    total = 0
    entries.each_with_index do |entry,i|
      key = entry.parent_id.to_s+"_"+entry.parent_type.to_s
      date_key = entry.month_val.to_s+"_"+entry.year_val.to_s
      inv_amount = entry.inv_amount||0
      pay_amount = entry.pay_amount||0
      prv_invoice = entry.prv_invoice_amount||0
      prv_payment = entry.prv_payment_amount||0
      prev_balance = prv_invoice -  prv_payment
      balance = inv_amount - pay_amount
      inv_currency = entry.inv_currency.present? ? entry.inv_currency : syscurrency
      pay_currency = entry.pay_currency.present? ? entry.pay_currency : syscurrency
      data[key] = {name: entry.name, prevBalance: '%.2f' % prev_balance, syscurrency: syscurrency, parent_id: entry.parent_id, parent_type: entry.parent_type} if data[key].blank?
      data[key][:range] = {} if data[key][:range].blank?
      data[key][:range][date_key] = {inv_amount: '%.2f' % inv_amount, pay_amount: '%.2f' % pay_amount, inv_currency: inv_currency, pay_currency: pay_currency, balance: '%.2f' % balance}
    end

    accName = []
    data.each do |key, val|
      key = val[:parent_id].to_s+"_"+val[:parent_type].to_s
      prev_balance = accBalace =  val[:prevBalance].to_f
      balance = 0
      val[:range].each do |key, entry|
        balance += entry[:balance].to_f
      end
      accName << key if accBalace == 0
      current_balance = balance+prev_balance.to_f
      data[key].store(:current_balance, '%.2f' % current_balance)
      total += current_balance.to_f
    end
    data = data.except!(*accName)
    [data].push('%.2f' % total)
  end

  def getExportData(user_id, group_id, projId, from, to)
    data = {headers: {}, data: []}
    reportData = calcReportData(user_id, group_id, projId, from, to)
    data[:headers] = {account:  l(:field_account), labels: '', prev_bal: l(:label_previous)+' '+l(:wk_field_balance)}
    reportData[:periods].each do |monthVal|
      data[:headers].store(monthVal, monthVal[0].to_s+' '+I18n.t("date.abbr_month_names")[monthVal[1]].to_s)
    end
    data[:headers].store('cur_bal',  l(:label_current)+' '+l(:wk_field_balance))
    reportData[:data].first.each do |key, val|
      details = {name: val[:name], label: '', prev_bal: '', curr_bal: ''}
      reportData[:periods].each do |monthVal|
        details.store(monthVal, '')
      end
      data[:data] << details
      invDetails = {label: '', invoice: l(:label_invoice), inv_prev_balance: ''}
      payDetails = {label: '', payment: l(:label_txn_payment), pay_prev_balance: ''}
      balDetails = {label: '', balance: l(:wk_field_balance), bal_prev_balance: val[:prevBalance]}
      val[:range].each do |key, entry|
        invDetails.store(key, entry[:inv_currency]+' '+entry[:inv_amount])
        payDetails.store(key, entry[:pay_currency]+' '+entry[:pay_amount])
        balDetails.store(key, entry[:inv_currency]+' '+entry[:balance])
      end
      invDetails.store('cur_bal', '')
      payDetails.store('cur_bal', '')
      balDetails.store('cur_bal', val[:current_balance])
      data[:data] << invDetails
      data[:data] << payDetails
      data[:data] << balDetails
    end
    total ={}
    reportData[:periods].each do |monthVal|
      total.store(monthVal, '')
    end
    total.merge!({acc: '',label: '', total: 'Total', allTotal: reportData[:data].last})
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

    pdf.SetFontStyle('B', 13)
    pdf.RDMMultiCell(table_width, 5, data[:location], 0, 'C')
    pdf.RDMMultiCell(table_width, 5, l(:report_account_payable), 0, 'C')
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
        pdf.SetFontStyle('', 8)
        pdf.SetFontStyle('B', 8) if entry == data[:data].last || key.to_s == 'name'
        border = 1 if entry == data[:data].last
        pdf.RDMCell(width, row_Height, value.to_s, border, 0, 'C', 0)
      }
      pdf.ln
    end
    pdf.Output
  end
end

