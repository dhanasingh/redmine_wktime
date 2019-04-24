module WksurveyHelper
	include WktimeHelper

  def getSurveyStatusArr
		{
			"" => '',
			l(:label_new) => 'N',
			l(:label_open) => 'O',
			l(:label_close) => 'C',
			l(:label_archived) => 'A'
		}
  end

  def getQuestionType
		{
			l(:label_check_box) => 'CB',
			l(:label_radio_button) => 'RB',
			l(:label_text_box) => 'TB',
			l(:label_text_area) => 'MTB'
		}
	end
	
	def getUserGroup
		
		groupNames = Hash.new
		groupNames[''] = ''
		(Group.sorted.all).each do |group| 
			groupNames[group.name] = group.id
		end
		groupNames
	end

  def getSurveyFor
		{
			"" => '',
			l(:label_project) => 'Project',
			l(:label_issue) => 'Issue',
			l(:label_accounts) => 'Accounts',
			l(:label_contact) => 'Contact'
		}
  end

  def isStatusNew(status)
		ret = false
		if status != 'N'
			ret = true
		end
		ret
	end

	def checkEditSurveyPermission
		validateERPPermission("E_SUR")
	end 
end
