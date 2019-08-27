class WksuppliercontactController < WkcontactController
	unloadable
	menu_item :wkrfq

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
		return validateERPPermission("B_PUR_PRVLG") || validateERPPermission("A_PUR_PRVLG") 
	end
	
	def check_crm_admin_and_redirect
	  unless validateERPPermission("A_PUR_PRVLG") 
	    render_403
	    return false
	  end
    end
	
	def deletePermission
		validateERPPermission("A_PUR_PRVLG")
	end
	
	def getAccountLbl
		l(:label_supplier_account)
	end
	
	def lblNewContact
		l(:label_new_item, l(:label_supplier_contact))
	end
	
	def contactLbl
		l(:label_supplier_contact)
	end

end
