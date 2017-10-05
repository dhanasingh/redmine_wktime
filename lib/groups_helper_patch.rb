require_dependency '../app/helpers/groups_helper'
require 'application_helper'
module GroupsHelper

	Group.class_eval do
	    has_many :group_permissions, foreign_key: 'group_id',  class_name: 'WkGroupPermission'
		has_many :permissions, through: :group_permissions
	end

	def group_settings_tabs(group)
		tabs = []
		tabs << {:name => 'general', :partial => 'groups/general', :label => :label_general}
		tabs << {:name => 'users', :partial => 'groups/users', :label => :label_user_plural} if group.givable?
		tabs << {:name => 'memberships', :partial => 'groups/memberships', :label => :label_project_plural}
		tabs << {:name => 'permissions', :partial => 'wkpermission/permissions', :label => :label_erp_permission}
		tabs
	end
	
end