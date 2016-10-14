module WkinvoiceHelper

include WktimeHelper

    def options_for_wktime_account()
		accArr = Array.new
		accArr << [ "", ""]
		accname = WkAccount.all
		#Project.project_tree(projects) do |proj_name, level|
		if !accname.blank?
			accname.each do | entry|
				accArr << [ entry.name, entry.id ]
			end
		end
		accArr
	end
end
