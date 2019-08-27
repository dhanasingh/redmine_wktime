class WkcrmcontactController < WkcontactController
  unloadable
  menu_item :wklead
	
	def getContactType
		'C'
	end
	
	def lblNewContact
		l(:label_new_item, l(:label_contact))
	end

end
