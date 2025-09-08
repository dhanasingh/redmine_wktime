module WkdashboardHelper
	# Return the graphs with its type
	# key - graph name, value - graph type
	include WkreportHelper
	include WktimeHelper

  def get_graphs_yaml_path
		permittedfiles = []
		ymlFiles = Dir["plugins/redmine_wktime/lib/wkdashboard/*.rb"].map{ |file| file }
		ymlFiles.each do |file|
			fileName = File.basename(file).split("_").first
			nonPermChart = !['graph001', 'graph002', 'graph003', 'graph004', 'graph005', 'graph006'].include?(fileName)
			if(nonPermChart || (fileName == 'graph001' && showAttendance) || (fileName == 'graph002' && showExpense) ||
				(fileName == 'graph003' && showCRMModule) || (fileName == 'graph004' && showBilling && validateERPPermission("M_BILL")) ||
				(fileName == 'graph005' && showInventory) || (fileName == 'graph006' && showAccounting))
					permittedfiles << file
			end
		end
		permittedfiles
  end

  def options_for_period_select(value)
		options_for_select([
							[l(:label_this_week), 'current_week'],
							[l(:label_last_week), 'last_week'],
							[l(:label_this_month), 'current_month'],
							[l(:label_last_month), 'last_month'],
							[l(:label_this_year), 'current_year'],
    					[l(:label_custom_range), 'custom']],
							value.blank? ? 'current_month' : value)
  end

  def showDashboard
		!Setting.plugin_redmine_wktime['wktime_enable_dashboards_module'].blank? &&
			Setting.plugin_redmine_wktime['wktime_enable_dashboards_module'].to_i == 1
  end
end
