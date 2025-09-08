# Shown users attachment in myaccount page
module SendPatch::MyControllerPatch
	def self.included(base)
		base.class_eval do
			helper WkdocumentHelper
	  	end
	end
end