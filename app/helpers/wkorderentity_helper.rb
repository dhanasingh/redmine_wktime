module WkorderentityHelper
	def getRfqArray(needBlank)
		rfqArr = WkRfq.all.order(id: :desc).pluck(:name, :id)
		rfqArr.unshift(["",'']) if needBlank
		rfqArr
	end
	
	def options_for_rfq_select(selectedValue, needBlank)
		options_for_select(getRfqArray(needBlank),
							selectedValue.blank? ? '' : selectedValue)
	end
	
	def getInvoiceIds(rfqId, invoiceType)
		sqlStr = getRfqOrderSqlStr + " where rfq.id = #{rfqId}"
		case invoiceType
			when 'Q'
			  invIdArr = WkRfq.find_by_sql(sqlStr).map {|i| i.quote_id }
			when 'PO'
			  invIdArr = WkRfq.find_by_sql(sqlStr).map {|i| i.purchase_order_id }
			else
			  invIdArr = WkRfq.find_by_sql(sqlStr).map {|i| i.supplier_inv_id }
		end
		invIdArr
	end
	
	def getRfqOrderSqlStr
		sqlStr = "select rfq.id as rfq_id, rq.quote_id, rp.purchase_order_id, rs.supplier_inv_id from wk_rfqs rfq" +
				" left join wk_rfq_quotes rq on (rfq.id = rq.rfq_id)" +
				" left join wk_po_quotes rp on (rp.quote_id = rq.quote_id)"+
				" left join wk_po_supplier_inv rs on (rs.purchase_order_id = rp.purchase_order_id)"
	end
end
