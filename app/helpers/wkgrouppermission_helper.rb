module WkgrouppermissionHelper
  include WktimeHelper

  def getPermissionModules
    modules = {
      "Inventory" => l(:label_inventory),
      "Shift Scheduling" => l(:label_scheduling),
      "Survey" => l(:label_survey),
      "CRM" => l(:label_crm),
      "Billing" => l(:label_wk_billing),
      "Accounting" => l(:label_accounting),
      "Purchase" => l(:label_purchasing),
      "Report" => l(:label_report),
      "ATTENDANCE" => l(:report_attendance),
      "PAYROLL" => l(:label_payroll),
      "HR" => l(:label_hr),
      "" => l(:label_general)
    }
    addMod = call_hook(:helper_permission_modules)
		if addMod.present?
			addMod = eval(addMod)
      puts addMod
      modules =  modules.merge(addMod)
    end
    modules
  end
end
