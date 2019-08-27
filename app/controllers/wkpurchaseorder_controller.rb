# ERPmine - ERP for service industry
# Copyright (C) 2011-2017  Adhi software pvt ltd
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
class WkpurchaseorderController < WksupplierorderentityController
  unloadable
  menu_item :wkrfq

	@@pomutex = Mutex.new

	def newSupOrderEntity(parentId, parentType)
		super
		if params[:quote_id].blank? || params[:rfq_id].blank?
			errorMsg = ""
			errorMsg = l(:error_please_select_rfq) + " <br/>" if params[:rfq_id].blank?
			errorMsg = errorMsg + l(:error_please_select_winning_quote) + " <br/>" if params[:quote_id].blank?
			flash[:error] = errorMsg
			redirect_to :action => 'new'
		else
			rfqQuotEntry = WkRfqQuote.where(:quote_id => params[:quote_id].to_i)
			@rfqQuotObj = rfqQuotEntry.blank? || rfqQuotEntry[0].blank? ? nil : rfqQuotEntry[0]
			if !params[:populate_items].blank? && params[:populate_items] == '1'
				@invoiceItem = WkInvoiceItem.where(:invoice_id => @rfqQuotObj.quote_id).select(:name, :rate, :amount, :quantity, :item_type, :currency, :project_id, :modifier_id,  :invoice_id, :original_amount, :original_currency)
			end		
		end			
	end
	
	def editOrderEntity
		super
		unless params[:invoice_id].blank?
			@poObj = WkPoQuote.find(@invoice.po_quote.id) unless @invoice.blank?
		end
	end
	
	def saveOrderInvoice(parentId, parentType,  projectId, invDate,  invoicePeriod, isgenerate, getInvoiceType)
		begin			
			@@pomutex.synchronize do
				addInvoice(parentId, parentType,  projectId, invDate,  invoicePeriod, isgenerate, getInvoiceType)
			end				
		rescue => ex
		  logger.error ex.message
		end
	end
	
	def saveOrderRelations
		savePurchaseOrderQuotes(params[:po_id],  @invoice.id, params[:po_quote_id] )
	end
	
	def getRfqQuoteIds
		quoteIds = ""	
		rfqObj = ""
		rfqObj = WkInvoice.where(:id => getInvoiceIds(params[:rfq_id].to_i, 'Q', true), :parent_id => params[:parent_id].to_i, :parent_type => params[:parent_type]).order(:id)
		
		rfqObj.each do | entry|
			quoteIds <<  entry.id.to_s() + ',' + entry.invoice_number.to_s()  + "\n" 
		end
		respond_to do |format|
			format.text  { render :plain => quoteIds }
		end
	end
	
	def getInvoiceType
		'PO'
	end
	
	def getLabelInvNum
		l(:label_po_number)
	end
	
	def getLabelNewInv
		l(:label_new_pur_order)
	end
	
	def getHeaderLabel
		l(:label_purchase_order)
	end
	
	def getPopulateChkBox
		l(:label_populate_quote_items)
	end
	
	def getItemLabel
		l(:label_po_items)
	end
	
	def getDateLbl
		l(:label_po_date)
	end
	
	def requireQuoteDD
		true
	end
	
	def getAdditionalDD
		"wkpurchaseorder/poadditionaldd"
	end
	
	def getOrderNumberPrefix
		'wktime_po_no_prefix'
	end
	
	def getNewHeaderLbl
		l(:label_new_pur_order)
	end
	
	def getOrderContract(invoice)
		contractStr = nil
		quote = invoice.po_quote.quote
		unless quote.blank?
			contractStr = quote.invoice_number + " - " + quote.invoice_date.to_formatted_s(:long)
		end
		contractStr
	end
	
	def getOrderComponetsId
		'wktime_po_components'
	end
	
end
