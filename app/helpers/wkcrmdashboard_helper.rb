module WkcrmdashboardHelper
  include WktimeHelper

	def get_graphs_yaml_path
		permittedfiles = []
		ymlFiles = Dir["plugins/redmine_wktime/lib/wkcrmdashboard/*.rb"].map{ |file| file }
		ymlFiles.each do |file|
			fileName = File.basename(file).split("_").first
			nonPermChart = !['graph001', 'graph002', 'graph003', 'graph004', 'graph005', 'graph006', 'graph007'].include?(fileName)
			if(nonPermChart || (fileName == 'graph001' && showCRMModule) || (fileName == 'graph002' && showCRMModule) || (fileName == 'graph003' && showCRMModule) || (fileName == 'graph004' && showCRMModule) || (fileName == 'graph005' && showCRMModule))
					permittedfiles << file
			end
		end
		permittedfiles
  end

end
