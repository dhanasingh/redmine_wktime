module WkcustomfieldsHelper
include WktimeHelper

  def options_for_wk_field_format_select
    [['',''],[l(:label_accounts), 'company'],[l(:label_lead_plural), 'wk_lead'],[l(:label_contact_plural), 'crm_contact']]
  end

  def custom_fields_of_type_ids(type)
    CustomField.where(type: type, field_format: ['crm_contact', 'wk_lead', 'company']).ids
  end

  def options_for_section_custom_field(section)
    return_arr = [['','']]
    WkCustomField.where(display_as: section).all.each do |wcf|
      return_arr << [wcf.custom_field.name, wcf.custom_fields_id]
    end
    return_arr
  end

  def options_for_section_related_to(section)
    return_arr = [['','']]
    CustomField.where(id: WkCustomField.where(display_as: section).map(&:custom_fields_id)).map(&:type).uniq.each do |type|
      related_to = custom_field_hash[type]
      return_arr << [related_to, type]
    end
    return_arr.uniq

  end

  def options_for_project_select
    return_arr = [['','']]
    User.current.projects.select(:id, :name).each do |p|
      return_arr << [p.name,p.id]
    end
    return_arr
  end

  def options_for_document_type_select
    return_arr = [['','']]
    Enumeration.where(type: "DocumentCategory").each do |p|
      return_arr << [p.name,p.id]
    end
    return_arr
  end

  def options_for_custom_field_type_select
    [ ['' , ''],
      [l(:field_issue), 'IssueCustomField'],
      [l(:label_spent_time), 'TimeEntryCustomField'],
      [l(:label_project_plural) , 'ProjectCustomField'],
      [l(:label_version_plural) , 'VersionCustomField'],
      [l(:label_document_plural) , 'DocumentCustomField'],
      [l(:label_user_plural) , 'UserCustomField'],
      [l(:label_group_plural) , 'GroupCustomField'],
      [l(:enumeration_activities) , 'TimeEntryActivityCustomField'],
      [l(:enumeration_issue_priorities) , 'IssuePriorityCustomField'],
      [l(:enumeration_doc_categories) , 'DocumentCategoryCustomField'],
      [l(:label_wk_time), "WktimeCustomField"]
    ]
  end

  def custom_field_hash
    {'IssueCustomField'=>l(:field_issue),
    'TimeEntryCustomField'=>l(:label_spent_time),
    'ProjectCustomField'=>l(:label_project_plural) ,
    'VersionCustomField'=>l(:label_version_plural) ,
    'DocumentCustomField'=>l(:label_document_plural) ,
    'UserCustomField'=>l(:label_user_plural) ,
    'GroupCustomField'=>l(:label_group_plural) ,
    'TimeEntryActivityCustomField'=>l(:enumeration_activities) ,
    'IssuePriorityCustomField'=>l(:enumeration_issue_priorities) ,
    'DocumentCategoryCustomField'=> l(:enumeration_doc_categories) ,
    "WktimeCustomField"=>l(:label_wk_time)}
  end


  def options_for_wk_custom_field_select(wcf)
    options = []
    wcf.each do |cf|
      option = "#{cf.name} (" + l(:label_relates_to) + ' '
      options_for_custom_field_type_select.each do |ft|
        (cf.type.eql? ft[1]) ? option += ft[0] : next
        break
      end
      option += ' ' + l(:label_crm) + ' '
      options_for_wk_field_format_select.each do |ff|
        (cf.field_format.eql? ff[1]) ? option += ff[0] : next
        break
      end
      option += ' )'
      options << [option, cf.id]
    end
    options
  end

  def getRelationDict(entry)
    returnDict = {}
    if entry.custom_values.any?
      issues = Issue.where(id: entry.custom_values.where(custom_field: CustomField.where(type: 'IssueCustomField')).map(&:customized_id).uniq)
      issues.any? ? returnDict['issue'] = issues : nil
      time_entries = TimeEntry.where(id: entry.custom_values.where(custom_field: CustomField.where(type: 'TimeEntryCustomField')).map(&:customized_id).uniq)
      time_entries.any? ? returnDict['time_entry'] = time_entries : nil
      projects = Project.where(id: entry.custom_values.where(custom_field: CustomField.where(type: 'ProjectCustomField')).map(&:customized_id).uniq)
      projects.any? ? returnDict['project'] = projects : nil
      versions = Version.where(id: entry.custom_values.where(custom_field: CustomField.where(type: 'VersionCustomField')).map(&:customized_id).uniq)
      versions.any? ? returnDict['version'] = versions : nil
      documents = Document.where(id: entry.custom_values.where(custom_field: CustomField.where(type: 'DocumentCustomField')).map(&:customized_id).uniq)
      documents.any? ? returnDict['document'] = documents : nil
      users = User.where(id: entry.custom_values.where(custom_field: CustomField.where(type: 'UserCustomField')).map(&:customized_id).uniq)
      users.any? ? returnDict['user'] = users : nil
      groups = Group.where(id: entry.custom_values.where(custom_field: CustomField.where(type: 'GroupCustomField')).map(&:customized_id).uniq)
      groups.any? ? returnDict['group'] = groups : nil
      time_entry_activities = TimeEntryActivity.where(id: entry.custom_values.where(custom_field: CustomField.where(type: 'TimeEntryActivityCustomField')).map(&:customized_id).uniq)
      time_entry_activities.any? ? returnDict['time_entry_activity'] = time_entry_activities : nil
      issue_priorities = IssuePriority.where(id: entry.custom_values.where(custom_field: CustomField.where(type: 'IssuePriorityCustomField')).map(&:customized_id).uniq)
      issue_priorities.any? ? returnDict['issue_priority'] = issue_priorities : nil
      document_categories = DocumentCategory.where(id: entry.custom_values.where(custom_field: CustomField.where(type: 'DocumentCategoryCustomField')).map(&:customized_id).uniq)
      document_categories.any? ? returnDict['document_category'] = document_categories : nil
      wktimes = Wktime.where(id: entry.custom_values.where(custom_field: CustomField.where(type: 'WktimeCustomField')).map(&:customized_id).uniq)
      wktimes.any? ? returnDict['wktime'] = wktimes : nil
    end
    returnDict
  end

  def customValuesPagination(entries, wkcustomfield_id, sort_by)
    @cv_entry_count[wkcustomfield_id] = entries.count
    setCustomValuesLimitAndOffset(wkcustomfield_id)
    order_by = sort_by.split('-')[0]
    if sort_by.split('-')[1].eql? 'desc'
      order = 'desc'
    else
      order = 'asc'
    end
    case order_by
    when 'custom_field'
      entries = entries.order("custom_field_id " + order)
    when 'customized_type'
      entries = entries.order("customized_type " + order)
    when 'name'
      entries = entries.joins("LEFT JOIN issues AS i ON custom_values.customized_id = i.id AND custom_values.customized_type='Issue'").joins("LEFT JOIN projects AS p ON custom_values.customized_id = p.id AND custom_values.customized_type='Project'").joins("LEFT JOIN documents AS d ON custom_values.customized_id = d.id AND custom_values.customized_type='Document'").joins("LEFT JOIN time_entries AS t ON custom_values.customized_type='TimeEntry' AND t.id=custom_values.customized_id").joins("LEFT JOIN versions AS v ON custom_values.customized_type='Version' and v.id=custom_values.customized_id").order("COALESCE(i.subject, p.name, d.title, v.name) " + order)
    when 'updated_on'
      entries = entries.joins("LEFT JOIN issues AS i ON custom_values.customized_id = i.id AND custom_values.customized_type='Issue'").joins("LEFT JOIN projects AS p ON custom_values.customized_id = p.id AND custom_values.customized_type='Project'").joins("LEFT JOIN documents AS d ON custom_values.customized_id = d.id AND custom_values.customized_type='Document'").joins("LEFT JOIN time_entries AS t ON custom_values.customized_type='TimeEntry' AND t.id=custom_values.customized_id").joins("LEFT JOIN versions AS v ON custom_values.customized_type='Version' and v.id=custom_values.customized_id").order("COALESCE(i.updated_on, p.updated_on, d.created_on, t.updated_on, v.updated_on) " + order)
    when 'created_on'
      entries = entries.joins("LEFT JOIN issues AS i ON custom_values.customized_id = i.id AND custom_values.customized_type='Issue'").joins("LEFT JOIN projects AS p ON custom_values.customized_id = p.id AND custom_values.customized_type='Project'").joins("LEFT JOIN documents AS d ON custom_values.customized_id = d.id AND custom_values.customized_type='Document'").joins("LEFT JOIN time_entries AS t ON custom_values.customized_type='TimeEntry' AND t.id=custom_values.customized_id").joins("LEFT JOIN versions AS v ON custom_values.customized_type='Version' and v.id=custom_values.customized_id").order("COALESCE(i.created_on, p.created_on, d.created_on, t.created_on, v.created_on) " + order)
    else
      entries = entries.joins("LEFT JOIN issues AS i ON custom_values.customized_id = i.id AND custom_values.customized_type='Issue'").joins("LEFT JOIN projects AS p ON custom_values.customized_id = p.id AND custom_values.customized_type='Project'").joins("LEFT JOIN documents AS d ON custom_values.customized_id = d.id AND custom_values.customized_type='Document'").joins("LEFT JOIN time_entries AS t ON custom_values.customized_type='TimeEntry' AND t.id=custom_values.customized_id").joins("LEFT JOIN versions AS v ON custom_values.customized_type='Version' and v.id=custom_values.customized_id").order("COALESCE(i.created_on, p.created_on, d.created_on, t.created_on, v.created_on) desc")
    end
    @customValues[wkcustomfield_id] = entries.limit(@limit).offset(@offset)
  end

  def setCustomValuesLimitAndOffset(wkcustomfield_id)
    if api_request?
      @offset, @limit = api_offset_and_limit
      if !params[:limit].blank?
        @limit = params[:limit]
      end
      if !params[:offset].blank?
        @offset = params[:offset]
      end
    else
      @cv_entry_pages[wkcustomfield_id] = Paginator.new @cv_entry_count[wkcustomfield_id], per_page_option, params["pagewk#{wkcustomfield_id}"], "pagewk#{wkcustomfield_id}"
      @limit = @cv_entry_pages[wkcustomfield_id].per_page
      @offset = @cv_entry_pages[wkcustomfield_id].offset
    end
  end

end
