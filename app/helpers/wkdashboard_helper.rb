# ERPmine - ERP for service industry
# Copyright (C) 2011-  Adhi software pvt ltd
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
				(fileName == 'graph005' && showInventory) ||
					# Profit/Loss comes from the general ledger, which has no location dimension,
					# so hide it from location-restricted users (admins => accessible_location_ids nil).
					(fileName == 'graph006' && showAccounting && WkLocation.accessible_location_ids.nil?))
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
