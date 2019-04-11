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
      Rails.logger.error "Im there"
      issues = entry.custom_values.where(customized_type: 'Issue').map(&:customized).group_by { |x| x.id }
      issues.any? ? returnDict['issue'] = issues : nil
      time_entries = entry.custom_values.where(customized_type: 'TimeEntry').map(&:customized).group_by { |x| x.id }
      time_entries.any? ? returnDict['time_entry'] = time_entries : nil
      projects = entry.custom_values.where(customized_type: 'Project').map(&:customized).group_by { |x| x.id }
      projects.any? ? returnDict['project'] = projects : nil
      versions = entry.custom_values.where(customized_type: 'Version').map(&:customized).group_by { |x| x.id }
      versions.any? ? returnDict['version'] = versions : nil
      documents = entry.custom_values.where(customized_type: 'Document').map(&:customized).group_by { |x| x.id }
      documents.any? ? returnDict['document'] = documents : nil
      users = entry.custom_values.where(customized_type: 'User').map(&:customized).group_by { |x| x.id }
      users.any? ? returnDict['user'] = users : nil
      groups = entry.custom_values.where(customized_type: 'Group').map(&:customized).group_by { |x| x.id }
      groups.any? ? returnDict['group'] = groups : nil
      time_entry_activities = entry.custom_values.where(customized_type: 'TimeEntryActivity').map(&:customized).group_by { |x| x.id }
      time_entry_activities.any? ? returnDict['time_entry_activity'] = time_entry_activities : nil
      issue_priorities = entry.custom_values.where(customized_type: 'IssuePriority').map(&:customized).group_by { |x| x.id }
      issue_priorities.any? ? returnDict['issue_priority'] = issue_priorities : nil
      document_categories = entry.custom_values.where(customized_type: 'DocumentCategory').map(&:customized).group_by { |x| x.id }
      document_categories.any? ? returnDict['document_category'] = document_categories : nil
      wktimes = entry.custom_values.where(customized_type: 'TimeEntry').map(&:customized).group_by { |x| x.id }
      wktimes.any? ? returnDict['wktime'] = wktimes : nil
      Rails.logger.error "ANd there"
    end
    returnDict
  end

  def customValuesPagination(entries, wkcustomfield_id, sort_by, filter=nil)
    unless sort_by.nil?
      order_by = sort_by.split('-')[0]

      if sort_by.split('-')[1].eql? 'desc'
        order = 'desc'
      else
        order = 'asc'
      end
    end
    unless filter.nil?
      unless filter['custom_field'].nil?
        entries = entries.where(custom_field_id: filter['custom_field'])
      end
      unless filter['relatedTo'].nil?
        entries = entries.where(custom_field_id: CustomField.where(type: filter['relatedTo']).ids)
      end
      unless filter['name'].nil?
        name = filter['name']
        entries = entries.joins("LEFT JOIN issues AS i ON custom_values.customized_id = i.id AND custom_values.customized_type='Issue'").joins("LEFT JOIN projects AS p ON custom_values.customized_id = p.id AND custom_values.customized_type='Project'").joins("LEFT JOIN documents AS d ON custom_values.customized_id = d.id AND custom_values.customized_type='Document'").joins("LEFT JOIN time_entries AS t ON custom_values.customized_type='TimeEntry' AND t.id=custom_values.customized_id").joins("LEFT JOIN versions AS v ON custom_values.customized_type='Version' and v.id=custom_values.customized_id").where("LOWER(i.subject) LIKE LOWER('%#{name}%') OR LOWER(p.name) LIKE LOWER('%#{name}%') OR LOWER(d.title) LIKE LOWER('%#{name}%') OR LOWER(v.name) LIKE LOWER('%#{name}%')")
      end
      unless filter['creation_date_from'].nil? and filter['creation_date_to'].nil?
        from = Date.parse(filter['creation_date_from']) unless filter['creation_date_from'].nil?
        to = Date.parse(filter['creation_date_to']) unless filter['creation_date_to'].nil?
        if !from.nil? and !to.nil?
          entries = entries.joins("LEFT JOIN issues AS i ON custom_values.customized_id = i.id AND custom_values.customized_type='Issue'").joins("LEFT JOIN projects AS p ON custom_values.customized_id = p.id AND custom_values.customized_type='Project'").joins("LEFT JOIN documents AS d ON custom_values.customized_id = d.id AND custom_values.customized_type='Document'").joins("LEFT JOIN time_entries AS t ON custom_values.customized_type='TimeEntry' AND t.id=custom_values.customized_id").joins("LEFT JOIN versions AS v ON custom_values.customized_type='Version' and v.id=custom_values.customized_id").where("COALESCE(i.created_on, p.created_on, d.created_on, t.created_on, v.created_on) >= ? AND COALESCE(i.created_on, p.created_on, d.created_on, t.created_on, v.created_on) <= ?", from, to)
        elsif !from.nil?
          entries = entries.joins("LEFT JOIN issues AS i ON custom_values.customized_id = i.id AND custom_values.customized_type='Issue'").joins("LEFT JOIN projects AS p ON custom_values.customized_id = p.id AND custom_values.customized_type='Project'").joins("LEFT JOIN documents AS d ON custom_values.customized_id = d.id AND custom_values.customized_type='Document'").joins("LEFT JOIN time_entries AS t ON custom_values.customized_type='TimeEntry' AND t.id=custom_values.customized_id").joins("LEFT JOIN versions AS v ON custom_values.customized_type='Version' and v.id=custom_values.customized_id").where("COALESCE(i.created_on, p.created_on, d.created_on, t.created_on, v.created_on) >= ?", from)
        elsif !to.nil?
          entries = entries.joins("LEFT JOIN issues AS i ON custom_values.customized_id = i.id AND custom_values.customized_type='Issue'").joins("LEFT JOIN projects AS p ON custom_values.customized_id = p.id AND custom_values.customized_type='Project'").joins("LEFT JOIN documents AS d ON custom_values.customized_id = d.id AND custom_values.customized_type='Document'").joins("LEFT JOIN time_entries AS t ON custom_values.customized_type='TimeEntry' AND t.id=custom_values.customized_id").joins("LEFT JOIN versions AS v ON custom_values.customized_type='Version' and v.id=custom_values.customized_id").where("COALESCE(i.created_on, p.created_on, d.created_on, t.created_on, v.created_on) <= ?", to)
        end
      end
      unless filter['update_date_from'].nil? and filter['update_date_to'].nil?
        from = Date.parse(filter['update_date_from']) unless filter['update_date_from'].nil?
        to = Date.parse(filter['update_date_to']) unless filter['update_date_to'].nil?
        if !from.nil? and !to.nil?
          entries = entries.joins("LEFT JOIN issues AS i ON custom_values.customized_id = i.id AND custom_values.customized_type='Issue'").joins("LEFT JOIN projects AS p ON custom_values.customized_id = p.id AND custom_values.customized_type='Project'").joins("LEFT JOIN documents AS d ON custom_values.customized_id = d.id AND custom_values.customized_type='Document'").joins("LEFT JOIN time_entries AS t ON custom_values.customized_type='TimeEntry' AND t.id=custom_values.customized_id").joins("LEFT JOIN versions AS v ON custom_values.customized_type='Version' and v.id=custom_values.customized_id").where("COALESCE(i.updated_on, p.updated_on, d.created_on, t.updated_on, v.updated_on) >= ? AND COALESCE(i.updated_on, p.updated_on, d.created_on, t.updated_on, v.updated_on) <= ?", from, to)
        elsif !from.nil?
          entries = entries.joins("LEFT JOIN issues AS i ON custom_values.customized_id = i.id AND custom_values.customized_type='Issue'").joins("LEFT JOIN projects AS p ON custom_values.customized_id = p.id AND custom_values.customized_type='Project'").joins("LEFT JOIN documents AS d ON custom_values.customized_id = d.id AND custom_values.customized_type='Document'").joins("LEFT JOIN time_entries AS t ON custom_values.customized_type='TimeEntry' AND t.id=custom_values.customized_id").joins("LEFT JOIN versions AS v ON custom_values.customized_type='Version' and v.id=custom_values.customized_id").where("COALESCE(i.updated_on, p.updated_on, d.created_on, t.updated_on, v.updated_on) >= ?", from)
        elsif !to.nil?
          entries = entries.joins("LEFT JOIN issues AS i ON custom_values.customized_id = i.id AND custom_values.customized_type='Issue'").joins("LEFT JOIN projects AS p ON custom_values.customized_id = p.id AND custom_values.customized_type='Project'").joins("LEFT JOIN documents AS d ON custom_values.customized_id = d.id AND custom_values.customized_type='Document'").joins("LEFT JOIN time_entries AS t ON custom_values.customized_type='TimeEntry' AND t.id=custom_values.customized_id").joins("LEFT JOIN versions AS v ON custom_values.customized_type='Version' and v.id=custom_values.customized_id").where("COALESCE(i.updated_on, p.updated_on, d.created_on, t.updated_on, v.updated_on) <= ?", to)
        end
      end
    end
    @cv_entry_count[wkcustomfield_id] = entries.count
    setCustomValuesLimitAndOffset(wkcustomfield_id)
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

  def setCustomValuesFilter(params, section)
    filter = {}
    filter['name']= params[:linkTo][section.to_s] unless params[:linkTo].nil? or params[:linkTo][section.to_s].nil? or params[:linkTo][section.to_s]==''
    filter['custom_field']= params[:cfName][section.to_s] unless params[:cfName].nil? or params[:cfName][section.to_s].nil? or params[:cfName][section.to_s]==''
    filter['relatedTo']= params[:relatedTo][section.to_s] unless params[:relatedTo].nil? or params[:relatedTo][section.to_s].nil? or params[:relatedTo][section.to_s]==''
    filter['creation_date_from'] = params[:cfrom][section.to_s] unless params[:cfrom].nil? or params[:cfrom][section.to_s].nil? or params[:cfrom][section.to_s]==''
    filter['creation_date_to'] = params[:cto][section.to_s] unless params[:cto].nil? or params[:cto][section.to_s].nil? or params[:cto][section.to_s]==''
    filter['update_date_from'] = params[:ufrom][section.to_s] unless params[:ufrom].nil? or params[:ufrom][section.to_s].nil? or params[:ufrom][section.to_s]==''
    filter['update_date_to'] = params[:uto][section.to_s] unless params[:uto].nil? or params[:uto][section.to_s].nil? or params[:uto][section.to_s]==''
    filter.clone
  end

end
