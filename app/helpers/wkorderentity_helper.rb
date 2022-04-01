module WkorderentityHelper
include WkcrmHelper

	def getRfqArray(needBlank)
		rfqArr = WkRfq.all.order(id: :desc).pluck(:name, :id)
		rfqArr.unshift(["",'']) if needBlank
		rfqArr
	end

	def getRfqQuoteArray(needBlank, id)
		rfqQuoteObj = WkRfqQuote.includes(:quote).where(:rfq_id => id, :is_won => true).order(:id) #getInvoiceIds(id, 'Q', true)
		rfqQuoteArr = rfqQuoteObj.collect {|i| [i.quote.invoice_number, i.quote.id]  }
		rfqQuoteArr.unshift(["",'']) if needBlank
		rfqQuoteArr
	end

	def getRfqPoArray(needBlank, id, parent_type, parent_id)
		rfqPoArr = Array.new
		rfqObj = 	WkInvoice.joins("LEFT JOIN wk_po_quotes ON wk_po_quotes.purchase_order_id = wk_invoices.id ")
		.joins("LEFT JOIN wk_rfq_quotes ON wk_rfq_quotes.quote_id=wk_po_quotes.quote_id")
		.where("parent_id" => parent_id, "parent_type" => parent_type, "invoice_type" => 'PO', "wk_rfq_quotes.rfq_id" => id.present? ? id  : nil, "status" => 'o')
		rfqPoArr = rfqObj.collect{|i| [i.invoice_number.to_s + " - " + i.confirm_num.to_s, i.id] }
		rfqPoArr.unshift(["",'']) if needBlank
		rfqPoArr
	end

	def options_for_rfq_select(selectedValue, needBlank)
		options_for_select(getRfqArray(needBlank),
							selectedValue.blank? ? '' : selectedValue)
	end

	def options_for_rfqQuote_select(needBlank, id)
		options_for_select(getRfqQuoteArray(needBlank, id))
	end

	def options_for_rfqPO_select(needBlank, id, parent_type, parent_id)
		options_for_select(getRfqPoArray(needBlank, id, parent_type, parent_id))
	end

	def getInvoiceIds(rfqId, invoiceType, requireWonQuote)
		sqlStr = getRfqOrderSqlStr + " where rfq.id = #{rfqId}"
		if requireWonQuote
			sqlStr = sqlStr + " and rq.is_won = #{booleanFormat(true)} "
		end
		case invoiceType
			when 'Q'
			  invIdArr = WkRfq.find_by_sql(sqlStr).map {|i| i.quote_id }
			when 'PO'
				invIdArr = rfqId != 0 ? WkRfq.find_by_sql(sqlStr).map {|i| i.purchase_order_id } : WkPoQuote.getPurchaseOrder.pluck(:purchase_order_id)
			else
			  invIdArr = WkRfq.find_by_sql(sqlStr).map {|i| i.supplier_inv_id }
		end
		invIdArr
	end

	def getRfqOrderSqlStr
		sqlStr = "select rfq.id as rfq_id, rq.quote_id, rp.purchase_order_id, rs.supplier_inv_id from wk_rfqs rfq" +
				" left join wk_rfq_quotes rq on (rfq.id = rq.rfq_id )" +
				" left join wk_po_quotes rp on (rp.quote_id = rq.quote_id)"+
				" left join wk_po_supplier_invoices rs on (rs.purchase_order_id = rp.purchase_order_id)"
	end

	def saveRfqQuotes(id, rfqId, quoteId, isWon, winningNote)
		rfqQuote = nil
		if id.blank?
			rfqQuote = WkRfqQuote.new
		else
			rfqQuote = WkRfqQuote.find(id)
		end
		rfqQuote.rfq_id = rfqId
		rfqQuote.quote_id = quoteId
		rfqQuote.is_won = isWon.blank? ? false : isWon
		if rfqQuote.is_won.blank? || rfqQuote.is_won_changed?
			rfqQuote.won_date =  rfqQuote.is_won ? Date.today : nil
		end
		rfqQuote.winning_note = winningNote
		rfqQuote.save()
	end

	def savePurchaseOrderQuotes(id, poId, quoteId)
		poQuote = nil
		if id.blank?
			poQuote = WkPoQuote.new
		else
			poQuote = WkPoQuote.find(id)
		end
		poQuote.purchase_order_id = poId
		poQuote.quote_id = quoteId
		poQuote.save()
	end

	def savePoSupInv(id, poId, supInvId)
		poSI = nil
		if id.blank?
			poSI = WkPoSupplierInvoice.new
		else
			poSI = WkPoSupplierInvoice.find(id)
		end
		poSI.purchase_order_id = poId
		poSI.supplier_inv_id = supInvId
		poSI.save()
	end

	def getInvoiceItemType(invoice_item)
		type = invoice_item.item_type
		invoice = invoice_item.invoice
		accProj = WkAccountProject.getTax(invoice_item.project_id, invoice.parent_type, invoice.parent_id).first
		billing_type = accProj&.billing_type
		itemtype  = ''
		case(type)
		when 'i'
			itemtype = invoice&.invoice_type == 'I' ? (billing_type == 'FC' ? l(:label_fixed_cost) : l(:field_hours)) : ''
		when 'm'
			itemtype = l(:label_material)
		when 'a'
			itemtype = l(:label_rental)
		when 'e'
			itemtype = l(:label_expenses)
		else
			itemtype = '';
		end
	end

	def getSIStatus
    {
			l(:label_open) => 'o',
			l(:label_closed_issues) => 'c',
			l(:label_fullfilled) => 'f',
			l(:label_delivered) => 'd'
    }
  end
end
