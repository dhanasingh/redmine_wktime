module WkdashboardHelper
	# Return the graphs with its type
	# key - graph name, value - graph type 
	include WkreportHelper
	include WktimeHelper
	include Redmine::I18n
  
  def get_graphs_yaml_path
		permittedfiles = []
		ymlFiles = Dir["plugins/redmine_wktime/config/wkdashboard/*.yml"].map{ |file| file }
		ymlFiles.each do |file|
			fileName = File.basename(file).split("_").first
			nonPermChart = !['001', '002', '003', '004', '005', '006'].include?(fileName)
			if(nonPermChart || (fileName == '001' && showAttendance) || (fileName == '002' && showExpense) ||
				(fileName == '003' && showCRMModule) || (fileName == '004' && showBilling && validateERPPermission("M_BILL")) ||
				(fileName == '005' && showInventory) || (fileName == '006' && showAccounting))
					permittedfiles << file
			end	
		end
		permittedfiles
  end
  
  def label_check(l_name)     
      I18n.t( l_name, default: l_name )
  end

  def options_for_period_select(value)
		options_for_select([
							[l(:label_this_week), 'current_week'],
							[l(:label_last_week), 'last_week'],
							[l(:label_this_month), 'current_month'],
							[l(:label_last_month), 'last_month'],
							[l(:label_this_year), 'current_year']],
							value.blank? ? 'current_week' : value)
  end
	
  def showDashboard
		!Setting.plugin_redmine_wktime['wktime_enable_dashboards_module'].blank? &&
			Setting.plugin_redmine_wktime['wktime_enable_dashboards_module'].to_i == 1
  end
end
