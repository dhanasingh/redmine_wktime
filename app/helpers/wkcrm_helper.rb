# ERPmine - ERP for service industry
# Copyright (C) 2011-2021  Adhi software pvt ltd
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

module WkcrmHelper
include WkinvoiceHelper
include WkcrmenumerationHelper
include WkdocumentHelper

	def getLeadList(from, to, groupId, userId)
		userIdArr = nil
		if !userId.blank? && userId.to_i > 0
			userIdArr = [userId.to_i]
		elsif !groupId.blank? && groupId.to_i > 0
			userIdArr = getGroupUserIdsArr(groupId.to_i)
		end
		from = getFromDateTime(from)
		to = getToDateTime(to)
		leadList = WkLead.getLeadEntries(from, to, userIdArr)
		leadList
	end

	def getConversionRate(allLeads, from, to)
	    convRate =  nil
		convertedLeads = allLeads.where(:status => "C", :status_update_on => getFromDateTime(from) .. getToDateTime(to)).count
		totalLeads = allLeads.count
		convRate = ((convertedLeads.to_f/totalLeads.to_f)*100).round(2) if totalLeads>0
		convRate
	end

	def getActivityList(from, to, groupId, userId)
		userIdArr = nil
		if !userId.blank? && userId.to_i > 0
			userIdArr = [userId.to_i]
		elsif !groupId.blank? && groupId.to_i > 0
			userIdArr = getGroupUserIdsArr(groupId.to_i)
		end
		from = getFromDateTime(from)
		to = getToDateTime(to)
		activityList = WkCrmActivity.getActivitiesEntries(from, to, userIdArr)
		activityList
	end

	def getLeadStatusHash
		{
			"N" => l(:label_new),
			"A" =>l(:label_assigned),
			"IP" => l(:label_in_process),
			"C" => l(:label_converted),
			"RC" => l(:label_recycled),
			"D" =>l(:label_dead)
		}
	end

  def directionHash
		directionStatus = {
			"I" => l(:label_inbound),
			"O" => l(:label_outbound)
		}
		directionStatus
	end

	def activityStatusHash
		actStatus = {
			"NS"  => l(:label_not_started),
			"IP" =>  l(:default_issue_status_in_progress),
			"C" =>  l(:label_completed),
			"PI" =>  l(:label_pending_input),
			"D" =>  l(:label_deferred)
		}
		actStatus
	end

	def taskPriorityHash
		taskPriority ={
			"H" =>  l(:default_priority_high),
			"M" =>  l(:label_medium),
			"L"  => l(:default_priority_low)
		}
		taskPriority
	end

	def acttypeHash
		actType ={
			"C" =>  l(:label_call),
			"M" =>  l(:label_meeting),
			"T"  => l(:label_task)
		}
		actType
	end

	def relatedHash
		relatedType = {
			"WkAccount"  => l(:field_account),
			"WkCrmContact" =>  l(:label_contact),
			"WkLead"  => l(:label_lead),
			"WkOpportunity" =>  l(:label_opportunity)
		}
	end

	def oppType
		opportunityType = {
			"N" => l(:label_new_item, l(:label_business)),
			"E" => l(:label_existing) + " " + l(:label_business)
		}
		opportunityType
	end

	def salesStages
		salesStageHash = {
			"P" => l(:label_prospecting),
			"Q" => l(:label_qualification),
			"N" => l(:label_needs_analysis) + " " + l(:label_analysis),
			"V" => l(:label_value_proposition),
			"I" => l(:label_decision_makers),
			"PA" => l(:label_perception)+ " " + l(:label_analysis),
			"PP" => l(:label_proposal_quote),
			"NR" => l(:label_negotiation),
			"CW" => l(:field_closed_on)+ " " + l(:label_won),
			"CL" => l(:field_closed_on)+ " " + l(:label_lost)
		}
		salesStageHash
	end

	def leadSources
		leadSourcesHash = {
			"CC" => l(:label_cold)+ " " + l(:label_call),
			"EC" => l(:label_existing) + " " + l(:label_customer),
			"SG" => l(:label_self) + " " + l(:label_generated),
			"E" => l(:label_employee),
			"P" => l(:label_partner),
			"PR" => l(:field_is_public)+ " " + l(:label_relations),
			"DM" => l(:label_direct)+ " " + l(:field_address),
			"C" => l(:label_conference),
			"TS" => l(:label_trade)+ " " + l(:button_show),
			"W" => l(:label_website),
			"WM" => l(:label_word_of_mouth),
			"EM" => l(:field_address),
			"O" => l(:label_other)
		}
		leadSourcesHash
	end

	def salutationHash
		salType ={
		    "" =>  "",
			"MR" =>  l(:label_mr),
			"MS" =>  l(:label_ms),
			"MRS"  => l(:label_mrs),
			"D" =>  l(:label_dr),
			"P" =>  l(:label_prof)
		}
		salType
	end

	def relatedValues(relatedType, parentId, type, needBlank, isContactType, isAccountType, activity_type=nil)
		relatedArr = Array.new
		relatedId = nil
		if relatedType == "WkOpportunity"
			relatedId = WkOpportunity.all.order(:name)
		elsif relatedType == "WkLead"
			condStr = activity_type == "I" ? "=" : "!="
			relatedId = WkLead.includes(:contact)
			.where("(wk_leads.status != ? OR wk_leads.id = ?) AND wk_crm_contacts.contact_type" +condStr+ "'IC'","C", parentId)
			.order("wk_crm_contacts.first_name, wk_crm_contacts.last_name")
		elsif relatedType == "WkCrmContact"
			hookType = call_hook(:additional_type)
			if hookType.blank? || !isContactType
				relatedId = WkCrmContact.includes(:lead).where(:account_id => nil, :contact_id => nil).where(wk_leads: { status: ["C", nil] }).where(:contact_type => type).order(:first_name, :last_name)
			else
				relatedId = WkCrmContact.includes(:lead).where(:account_id => nil, :contact_id => nil).where(wk_leads: { status: ["C", nil] }).where("wk_crm_contacts.contact_type = '#{type}' or wk_crm_contacts.contact_type = '#{hookType}'").order(:first_name, :last_name)
			end
		else
			hookType = call_hook(:additional_type)
			if hookType.blank? || !isAccountType
				relatedId = WkAccount.where(:account_type => type).order(:name)
			else
				relatedId = WkAccount.where("wk_accounts.account_type = '#{type}' or wk_accounts.account_type = '#{hookType}'").order(:name)
			end
		end
		if !relatedId.blank?
			relatedId.each do | entry|
				if relatedType == "WkLead"
					relatedArr <<  [entry.contact.name, entry.id  ]
				elsif relatedType == "WkCrmContact"
					relatedArr <<  [entry.name, entry.id]
				else
					relatedArr << [entry.name, entry.id]
				end
			end
		end
		relatedArr.unshift(["", ""]) if needBlank
		relatedArr
	end

	def getAccordionSection(entity, curObj)
		accSections = ["wkcrmactivity"]
		case entity
		when "WkAccount"
			accSections = ["wkcrmactivity", "wkcrmcontact", "wkaccountproject", "wksurvey", "wkdocument"]
			accSections.push("wksalesquote", "wkopportunity") if curObj.account_type == "A"
			hookSection = call_hook(:view_accordion_section, {:entity => entity, :curObj => curObj})
			hookSection = hookSection.split(" ")
			sectionsToRemove = call_hook(:remove_existing_accordion_section, {:entity => entity, :curObj => curObj})
			sectionsToRemove = sectionsToRemove.split(" ")
		when "WkCrmContact"
			accSections = ["wkcrmactivity", "wkcrmcontact", "wkaccountproject", "wksurvey", "wkdocument"]
			accSections.push("wksalesquote", "wkopportunity") if curObj.contact_type == "C"
			hookSection = call_hook(:view_accordion_section, {:entity => entity, :curObj => curObj})
			hookSection = hookSection.split(" ")
			sectionsToRemove = call_hook(:remove_existing_accordion_section, {:entity => entity, :curObj => curObj})
			sectionsToRemove = sectionsToRemove.split(" ")
		when "WkInventoryItem"
			accSections = ["wkproductitem"]
		when "WkRfq"
			accSections = ["wkquote"]
		when "WkCrmActivity"
			accSections = ["wkdocument"]
		when "WkOpportunity"
			accSections = ["wkcrmactivity", "wkdocument","wksalesstagehistory"]
		when "WkLead"
			accSections = ["wkcrmactivity"]
			accSections.push("wkaccountproject","wksalesquote") if curObj.contact.contact_type == "C"
			accSections << "wkdocument" if validateERPPermission("A_REFERRAL")
		else
			accSections = ["wkcrmactivity"]
		end

		accSections -= sectionsToRemove unless sectionsToRemove.blank?
		unless hookSection.blank?
			accSections = accSections + hookSection
		end
		accSections
	end

	def convertSecToDays(seconds)
		days = seconds/(3600*24).to_f
		days.round(2)
	end

	def date_for_user_time_zone(y, m, d)
		if tz = User.current.time_zone
		  tz.local y, m, d
		else
		  Time.local y, m, d
		end
	end

	def getFromDateTime(dateVal)
		date_for_user_time_zone(dateVal.year, dateVal.month, dateVal.day).yesterday.end_of_day
	end

	def getToDateTime(dateVal)
		date_for_user_time_zone(dateVal.year, dateVal.month, dateVal.day).end_of_day
	end

	# This method returns billable project parents as hash
	# Hash has parent_type as key and parent_id as value
	def getProjectBillers(projectId)
		accProjects = WkAccountProject.where(project_id: projectId).order(:parent_type, :parent_id)
		parentIdHash = Hash.new
		parentIdHash["WkAccount"] = []
		parentIdHash["WkCrmContact"] = []
		accProjects.each do |entry|
			parentIdHash[entry.parent_type] = parentIdHash[entry.parent_type] << entry.parent_id
		end
		parentIdHash
	end

  def get_active_users
    users = User.active.map{|u| [u.name, u.id]}
    [["",""]] + users
  end

	def rf_status
		{
			"IH" => l(:label_hire),
			"INH" => l(:label_not_hire),
			"IN" => l(:label_none)
		}
	end

	def hiring_employees
		WkLead.hiring_employees.map{|l| [l.name, l.id]}
	end

	def get_crm_Users
		users = groupOfUsers
		users.shift()
		users
	end
end
