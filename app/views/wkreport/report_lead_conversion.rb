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
      leads[key]['Converted'] = lead.status_update_on.localtime.strftime("%Y-%m-%d %H:%M:%S") if lead.status == 'C'
      leads[key]['days'] = convertSecToDays(lead.status_update_on - lead.created_at) if lead.status == 'C'
      leads[key]['Assignee'] = lead.contact.assigned_user.name unless lead.contact.assigned_user.blank?
    end
    convRate = getConversionRate(leadList, from, to)
    data = {leads: leads, convRate: convRate, from: from.strftime("%d-%b-%Y"), to: to.strftime("%d-%b-%Y") }
  end
end