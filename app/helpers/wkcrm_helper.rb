module WkcrmHelper
include WkinvoiceHelper
	
	def getLeadList(from, to)
		WkLead.includes(:contact).where(:created_at => from .. to)
	end
	
	def getConversionRatio(allLeads, from, to)
		convertedLeads = allLeads.where(:status => 'C', :status_update_on => from .. to).count
		totalLeads = allLeads.count
		convRatio = (convertedLeads.to_f/totalLeads.to_f)*100 
		convRatio
	end
	
	def getActivityList(from, to)
		WkCrmActivity.includes(:parent).where(:start_date => from .. to)
	end

    def directionHash
		directionStatus = {
			'I' => l(:label_inbound),
			'O' => l(:label_outbound)
		}
		directionStatus	
	end
	
	def meetCallStatusHash
		mcStatus = {
			'P'  => l(:label_planned),
			'H' =>  l(:label_held),
			'NH' =>  l(:label_not_held)
		}
		mcStatus
	end
	
	def taskStatusHash
		taskStatus = {
			'NS'  => l(:label_not_started),
			'IP' =>  l(:default_issue_status_in_progress),
			'C' =>  l(:label_completed),
			'PI' =>  l(:label_pending_input),
			'D' =>  l(:label_deferred)
		}
		taskStatus
	end
	
	def taskPriorityHash
		taskPriority ={
			'H' =>  l(:default_priority_high),
			'M' =>  l(:label_medium),
			'L'  => l(:default_priority_low)
		}
		taskPriority
	end
	
	def acttypeHash
		actType ={
			'C' =>  l(:label_call),
			'M' =>  l(:label_meeting),
			'T'  => l(:label_task)
		}
		actType
	end
	
	def relatedHash
		relatedType = {
			'WkAccount'  => l(:label_account),
			'WkCrmContact' =>  l(:label_contact),
			'WkLead'  => l(:label_lead),
			'WkOpportunity' =>  l(:label_opportunity)			
		}
	end
	
	def oppType
		opportunityType = {
			'N' => l(:label_new_item, l(:label_business)),
			'E' => l(:label_existing) + " " + l(:label_business)
		}
		opportunityType	
	end
	
	def salesStages
		salesStageHash = {
			'P' => l(:label_prospecting),
			'Q' => l(:label_qualification),
			'N' => l(:label_needs_analysis) + " " + l(:label_analysis),
			'V' => l(:label_value_proposition),
			'I' => l(:label_decision_makers),
			'PA' => l(:label_perception)+ " " + l(:label_analysis),
			'PP' => l(:label_proposal_quote),
			'NR' => l(:label_negotiation),
			'CW' => l(:field_closed_on)+ " " + l(:label_won),
			'CL' => l(:field_closed_on)+ " " + l(:label_lost)
		}
		salesStageHash
	end
	
	def leadSources
		leadSourcesHash = {
			'CC' => l(:label_cold)+ " " + l(:label_call),
			'EC' => l(:label_existing) + " " + l(:label_customer),
			'SG' => l(:label_self) + " " + l(:label_generated),
			'E' => l(:label_employee),
			'P' => l(:label_partner),
			'PR' => l(:field_is_public)+ " " + l(:label_relations),
			'DM' => l(:label_direct)+ " " + l(:field_address),			
			'C' => l(:label_conference),
			'TS' => l(:label_trade)+ " " + l(:button_show),
			'W' => l(:label_website),
			'WM' => l(:label_word_of_mouth),
			'EM' => l(:field_address),
			'O' => l(:label_other)
		}
		leadSourcesHash
	end
	
	def salutationHash
		salType ={
		    '' =>  "",
			'MR' =>  l(:label_mr),
			'MS' =>  l(:label_ms),
			'MRS'  => l(:label_mrs),
			'D' =>  l(:label_dr),
			'P' =>  l(:label_prof)
		}
		salType
	end
	
	def relatedValues(relatedType)
		relatedArr = Array.new
		relatedId = nil
		if relatedType == "WkOpportunity"
			relatedId = WkOpportunity.all.order(:name)
		elsif relatedType == "WkLead"
			relatedId = WkLead.where.not(:status => 'C')
		elsif relatedType == "WkCrmContact"
			relatedId = WkCrmContact.where.not(:parent_type => 'WkLead').order(:last_name)
		else
			relatedId = WkAccount.where(:account_type => 'A').order(:name)
		end
		if !relatedId.blank?
			relatedId.each do | entry|				
				if relatedType == "WkLead" 
					relatedArr <<  [entry.contacts.last_name, entry.id  ]
				elsif relatedType == "WkCrmContact"
					relatedArr <<  [entry.last_name, entry.id]
				else
					relatedArr << [entry.name, entry.id]    
				end
			end
		end
		
		relatedArr
	end
	
	def getAccordionSection(entity)
		accSections = ['wkcrmactivity']
		case entity
		when 'WkAccount'
			accSections = ['wkcrmactivity', 'wkcrmcontact', 'wkopportunity']
		when 'WkCrmContact'
			accSections = ['wkcrmactivity', 'wkopportunity']
		else
			accSections = ['wkcrmactivity']
		end
		accSections
	end
	
end
