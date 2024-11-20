module SendPatch::CustomFieldsHelperPatch
	def self.included(base)
		CustomFieldsHelper::CUSTOM_FIELDS_TABS << {:name => 'WktimeCustomField', :partial => 'custom_fields/index', :label => :label_wk_time}
	end
end