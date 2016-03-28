module WkattendanceHelper	
	include WktimeHelper
	
	#Copied from UserHelper
	def users_status_options_for_select(selected)
		user_count_by_status = User.group('status').count.to_hash
		options_for_select([[l(:label_all), ''],
                        ["#{l(:status_active)} (#{user_count_by_status[1].to_i})", '1'],
                        ["#{l(:status_registered)} (#{user_count_by_status[2].to_i})", '2'],
                        ["#{l(:status_locked)} (#{user_count_by_status[3].to_i})", '3']], selected.to_s)
	end
	
	def getSettingCfId(settingId)
		cfId = Setting.plugin_redmine_wktime[settingId].blank? ? 0 : Setting.plugin_redmine_wktime[settingId].to_i
		cfId
	end
	
	def getLeaveIssueIds
		issueIds = ''
		if(Setting.plugin_redmine_wktime['wktime_leave'].blank?)
			issueIds = '-1'
		else
			Setting.plugin_redmine_wktime['wktime_leave'].each do |element|
				if issueIds!=''
					issueIds = issueIds +','
				end
			  listboxArr = element.split('|')
			  issueIds = issueIds + listboxArr[0]
			end
		end	
		issueIds
	end

end
