module WkcrmHelper
include WkinvoiceHelper

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
	
end
