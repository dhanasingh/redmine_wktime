class WksuppliercontactController < WkcontactController
	unloadable

	include WktimeHelper
  
	def getContactType
		'SC'
	end
	
	def getContactController
		'wksuppliercontact'
	end
	
	def getAccountType
		'S'
	end
	
	def check_permission		
		return isModuleAdmin('wktime_pur_group') || isModuleAdmin('wktime_pur_admin') 
	end
	
	def check_crm_admin_and_redirect
	  unless isModuleAdmin('wktime_pur_admin') 
	    render_403
	    return false
	  end
    end
	
	def deletePermission
		isModuleAdmin('wktime_pur_admin')
	end
	
	def getAccountLbl
		l(:label_supplier_account)
	end

end
f lblNewContact
		l(:label_new_item, l(:label_supplier_contact))
	end
	
	def contactLbl
		l(:label_supplier_contact)
	end

end
