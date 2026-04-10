module WkgrouppermissionHelper
  include WktimeHelper
 
  def getPermissionModules
    modules = {}
    
    WkPermission.distinct.pluck(:modules).each do |mod|
      key = mod.to_s
      if key.blank?
        modules[""] = l(:label_general)
      else
        # Convert module name to i18n key convention
        convention_key = "label_#{key.downcase.gsub(' ', '_')}".to_sym
        modules[key] = I18n.t(convention_key, default: key)
      end
    end
 
    modules[""] ||= l(:label_general)
    call_hook(:helper_permission_modules, {modules: modules})
    modules
  end
end