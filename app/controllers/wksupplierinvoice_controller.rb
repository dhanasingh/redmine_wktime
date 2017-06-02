class WksupplierinvoiceController < WkorderentityController
  unloadable



  # def index
  # end

  
	def getInvoiceType
		'SI'
	end
	
	def getHeaderLabel
		l(:label_supplier_invoice)
	end
	
	def getLabelNewInv
		l(:label_new_sup_invoice)
	end
	
	def isPopulateCheckBox
		true
	end
	
	def isPopulateCheckBoxLabel
		l(:label_populate_purchase_items)
	end
	
	def needBlankForProject
		true
	end
	
	def needRfqDd
		true
	end
	
	def getItemLabel
		l(:label_si_items)
	end
	
	def getLabelInvNum
		l(:label_sp_number)
	end
	
	def getDateLbl
		l(:label_sp_date)
	end
	
end
