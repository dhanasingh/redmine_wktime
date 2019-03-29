Deface::Override.new(:virtual_path => "issues/_list",
                     :name => "add_tr_style",
                     :add_to_attributes => "tr",
                     :attributes => {:style => "white-space: normal !important;"}
		    )
