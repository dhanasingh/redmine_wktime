class FtteHook < Redmine::Hook::ViewListener
	#Hook code to put Supervisor dropdown in Admin -> User edit page
	def view_users_form(context={})
		if context[:user].id?
			cond = "#{User.table_name}.lft >= #{context[:user].lft} and #{User.table_name}.rgt <= #{context[:user].rgt}"
			users = User.where.not(cond).order('firstname')
		else
			users = User.where.not(:lft => nil, :rgt => nil).order('firstname')
		end
		unless users.blank?
			usrList = users.collect {|t| ["#{t.firstname + ' ' + t.lastname}", t.id] }			
			usrList.unshift(["",""])
		end
		"<p>" + "#{context[:form].select :parent_id, usrList, :label => :label_ftte_supervisor}" + "</p>"
	end
	
	#Hook code to show Supervisor in "My account" page
	def view_my_account(context={})
		s = nil
		if !(context[:user].parent_id).blank?
			s = User.find(context[:user].parent_id)
		end		
		"<p>" + "#{label_tag l(:label_ftte_supervisor)} #{!s.nil? ? (s.firstname + ' ' + s.lastname) : '--None--'}" + "</p>"
	end
end