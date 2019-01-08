class WkcrmcontactController < WkcontactController
  unloadable
	
	def getContactType
		'C'
	end
	
	def lblNewContact
		l(:label_new_item, l(:label_contact))
	end

end
