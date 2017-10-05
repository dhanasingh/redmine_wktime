module WkpermissionHelper
include WktimeHelper

	

	def render_principals_for_new_group_permissions(group, limit=100)
		#scope = User.active.sorted.not_in_group(group).like(params[:q])
		scope = WkPermission.all
		principal_count = scope.count
		principal_pages = Redmine::Pagination::Paginator.new principal_count, limit, params['page']
		principals = scope.offset(principal_pages.offset).limit(principal_pages.per_page).to_a
		s = content_tag('div',
		  content_tag('div', permission_check_box_tags('permission_ids[]', principals), :id => 'principals'),
		  :class => 'objects-selection'
		)

		links = pagination_links_full(principal_pages, principal_count, :per_page_links => false) {|text, parameters, options|
		  link_to text, autocomplete_for_permission_group_path(group, parameters.merge(:q => params[:q], :format => 'js')), :remote => true
		}

		s + content_tag('span', links, :class => 'pagination')
	 end
	 
	 def permission_check_box_tags(name, principals)
		s = ''
		principals.each do |principal|
		  s << "<label>#{ check_box_tag name, principal.id, false, :id => nil } #{h principal.name}</label>\n"
		end
		s.html_safe
	 end

end
