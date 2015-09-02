class WkTimeEntryQuery < TimeEntryQuery
	def initialize(attributes=nil, *args)
		super attributes
		self.filters ||= {}
		#add_filter('spent_on', '*') unless filters.present?
	end
  
	def initialize_available_filters
		#add_available_filter "spent_on", :type => :date_past
		add_associations_custom_fields_filters :user
	end
end