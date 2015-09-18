class WkMailer < ActionMailer::Base
layout 'mailer'
helper :application
include Redmine::I18n
  
	def sendRejectionEmail(loginuser,user,wktime,unitLabel,unit)
		set_language_if_valid(user.language)
		if !unitLabel.blank?
			subject="#{l(:label_wk_reject_expense)} #{wktime.begin_date}"
			body= l(:label_wk_expense_reject)
			total="#{l(:label_total)} #{l(:label_wkexpense)}  : #{unit} #{wktime.hours}"
		else
			subject=" #{l(:label_wk_reject_timesheet)} #{wktime.begin_date}"
			body= l(:label_wk_timesheet_reject)
			total="#{l(:label_total)} #{l(:field_hours)} : #{wktime.hours}"
		end

		body +="\n #{l(:field_name)} : #{user.firstname} #{user.lastname} \n #{total}"
		body +="\n #{l(:label_wk_submittedon)} : #{wktime.submitted_on} \n #{l(:label_wk_rejectedby)} : #{loginuser.firstname} #{loginuser.lastname}"
		body +="\n #{l(:label_wk_rejectedon)} : #{wktime.statusupdate_on} \n #{l(:label_wk_reject_reason)} : #{wktime.notes}"
		body +="\n"
		mail :from => loginuser.mail,:to => user.mail, :subject => subject,:body => body
	end
	  
	def nonSubmissionNotification(user,startDate)
		set_language_if_valid(user.language)
		
		subject = "#{l(:label_wk_nonsub_mail_subject)}" + " " + startDate.to_s
		body = !Setting.plugin_redmine_wktime['wktime_nonsub_mail_message'].blank? ? 
		Setting.plugin_redmine_wktime['wktime_nonsub_mail_message'] : "You are receiving this notification for timesheet non submission"
		body += "\n #{l(:label_wk_submission_deadline)}" + " : " + "#{day_name(Setting.plugin_redmine_wktime['wktime_submission_deadline'].to_i)}"
		body += "\n #{l(:field_name)} : #{user.firstname} #{user.lastname} "
		body += "\n #{ l(:label_week) }" + " : " + startDate.to_s + " - " + (startDate+6).to_s
		
		mail :from => Setting.mail_from ,:to => user.mail, :subject => subject, :body => body
	end
	
	def submissionReminder(user, mngr, emailNotes)
		set_language_if_valid(user.language)
		
		subject = l(:wk_submission_reminder)
		body = l(:wk_sub_reminder_text)
		body += "\n" + emailNotes if !emailNotes.blank?
		
		mail :from => User.current.mail, :to => user.mail, :reply_to => User.current.mail, 
		:cc => mngr.blank? ? nil : mngr.mail, :subject => subject, :body => body
	end
	
	def approvalReminder(mgr, userList, emailNotes)
		set_language_if_valid(mgr.language)
		
		subject = l(:wk_approval_reminder)
		body = "#{l(:wk_appr_reminder_text)}" + "\n"
		body += userList
		body += "\n" + emailNotes if !emailNotes.blank?
		
		mail :from => User.current.mail, :to => mgr.mail, :reply_to => User.current.mail, :subject => subject, :body => body
	end
	
	def sendConfirmationMail(userList, isSub)
		set_language_if_valid(User.current.language)
		
		subject = isSub ? l(:wk_submission_reminder) : l(:wk_approval_reminder)
		body = (isSub ? "#{l(:wk_sub_confirmation_text)}" : "#{l(:wk_appr_confirmation_text)}" ) + "\n" + userList
		
		mail :from => User.current.mail, :to => User.current.mail, :subject => subject, :body => body
	end
 end
