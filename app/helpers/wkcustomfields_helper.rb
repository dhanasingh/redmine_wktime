module WkcustomfieldsHelper
include WktimeHelper

  def options_for_wk_field_format_select
    [['',''],[l(:label_accounts), 'company'],[l(:label_lead_plural), 'wk_lead'],[l(:label_contact_plural), 'crm_contact']]
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

end
