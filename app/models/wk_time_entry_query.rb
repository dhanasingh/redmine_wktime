# ERPmine - ERP for service industry
# Copyright (C) 2011-2016  Adhi software pvt ltd
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

class WkTimeEntryQuery < Query
	self.queried_class = TimeEntry
	
	def initialize(attributes=nil, *args)
		super attributes
		self.filters ||= {}
		#add_filter('spent_on', '*') unless filters.present?
	end
  
	def initialize_available_filters
		#add_available_filter "spent_on", :type => :date_past
		add_associations_custom_fields_filters :user
	end
	
	def user_cf_statement(tblAlias)
		# filters clauses
		#filters_clauses = []
		leftJoinClause = []
		whereClause = []
		sqlClause = []
		i = 0
		filters.each_key do |field|
		  #next if field == "subproject_id"
		  v = values_for(field).clone
		  next unless v and !v.empty?
		  operator = operator_for(field)
		  i = i + 1
		  if field =~ /cf_(\d+)$/
			# custom field
			sqlClause = sql_for_user_custom_field(field, operator, v, $1, i, tblAlias)
			leftJoinClause << sqlClause[0]
			whereClause << sqlClause[1]
		  end
		end if filters and valid?
		
		leftJoinClause.reject!(&:blank?)
		strLeftJoinClause = leftJoinClause.any? ? leftJoinClause.join(' ') : nil
		
		whereClause.reject!(&:blank?)
		strWhereClause = whereClause.any? ? whereClause.join(' AND ') : nil
		
		strUserCf = !strLeftJoinClause.blank? ? (strLeftJoinClause + (!strWhereClause.blank? ? (' WHERE ' + strWhereClause) : '')) : ''		
		
	end
	
	private
	
	def sql_for_user_custom_field(field, operator, value, custom_field_id, alias_num, tblAlias)		
		db_table = CustomValue.table_name
		db_field = 'value'
		filter = @available_filters[field]
		return nil unless filter
		if filter[:field].format.target_class && filter[:field].format.target_class <= User
		  if value.delete('me')
			value.push User.current.id.to_s
		  end
		end
		#not_in = nil
		#if operator == '!'
		  # Makes ! operator work for custom fields with multiple values
		#  operator = '!'
		#  not_in = 'NOT'
		#end
		customized_key = "id"
		customized_class = queried_class
		if field =~ /^(.+)\.cf_/
		  assoc = $1
		  customized_key = "#{assoc}_id"
		  customized_class = queried_class.reflect_on_association(assoc.to_sym).klass.base_class rescue nil
		  raise "Unknown #{queried_class.name} association #{assoc}" unless customized_class
		end
		where = sql_for_field(field, operator, value, db_table, db_field, true)
		if operator =~ /[<>]/
		  where = "(#{where}) AND #{db_table}.#{db_field} <> ''"
		end
		leftJoinClause = " LEFT OUTER JOIN #{db_table} cf#{alias_num} ON cf#{alias_num}.customized_type='#{customized_class}' AND cf#{alias_num}.customized_id=#{tblAlias}.id AND cf#{alias_num}.custom_field_id=#{custom_field_id}"
		whereClause = " (#{where.gsub(db_table,'cf' + alias_num.to_s)} AND (#{filter[:field].visibility_by_project_condition}))"
		return [leftJoinClause, whereClause]
	end	
end