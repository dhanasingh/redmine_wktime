module ReportLeadConversion
  include WkreportHelper

  def calcReportData(user_id, group_id, projId, from, to)
    if user_id.blank?
      user_id = validateERPPermission("B_CRM_PRVLG") ? User.current.id : 0
    end
    leads = {}
	  leadList = getLeadList(from, to, group_id, user_id)
    leadList.each do |lead|
      key = lead.id.to_s
      leads[key] = {}
      leads[key]['name'] = lead.contact.name
      leads[key]['status'] = getLeadStatusHash[lead.status]
      leads[key]['Created'] = lead.created_at.localtime.strftime("%Y-%m-%d %H:%M:%S")
      leads[key]['Converted'] = lead.status_update_on.localtime.strftime("%Y-%m-%d %H:%M:%S") || '' if lead.status == 'C'
      leads[key]['days'] = convertSecToDays(lead.status_update_on - lead.created_at) || '' if lead.status == 'C'
      leads[key]['Assignee'] = lead.contact.assigned_user.name || '' unless lead.contact.assigned_user.blank?
    end
    convRate = getConversionRate(leadList, from, to)
    data = {leads: leads, convRate: convRate, from: from.strftime("%d-%b-%Y"), to: to.strftime("%d-%b-%Y") }
  end

  def getExportData(user_id, group_id, projId, from, to)
    data = {headers: {}, data: []}
    reportData = calcReportData(user_id, group_id, projId, from, to)
    data[:headers] = {lead: l(:label_lead), status: l(:field_status), created: l(:field_created_on), converted: l(:label_converted), sal_cycle: l(:label_sales_cycle)+' '+l(:label_day_plural), assignee: l(:field_assigned_to)}
    reportData[:leads].each do |key, lead|
      data[:data] << {name: lead['name'], status: lead['status'], Created: lead['Created'], Converted:  lead['Converted'], days: lead['days'], assignee: lead['Assignee']}
    end
    unless reportData[:convRate].blank?
      convRate = {name: '', status: '', created: '', converted: '', rate: l(:label_conversion_rate), val: reportData[:convRate].to_f.to_s+' '+'%'}
      data[:data] << convRate
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
    pdf.RDMMultiCell(table_width, 5, l(:report_lead_conversion) + " " + l(:label_report), 0, 'C')
    pdf.RDMMultiCell(table_width, 5, data[:from].to_s+ " "+l(:label_date_to)+" "+ data[:to].to_s, 0, 'C')

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
        if entry == data[:data].last
          pdf.SetFontStyle('B', 8)
          border = 1
        end
        pdf.RDMCell(width, row_Height, value.to_s, border, 0, 'C', 1)
      }
      pdf.ln
    end
    pdf.Output
  end
end