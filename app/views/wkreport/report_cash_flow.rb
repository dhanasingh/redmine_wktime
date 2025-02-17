module ReportCashFlow
  include WkreportHelper
	require 'rbpdf'

  def calcReportData(user_id, group_id, projID, from, to)
		from = from.to_date
		to = to.to_date
		ledgerHash = Hash.new
    subLedgerHash = Hash.new
    totalHash = Hash.new
		ledgers = ['C', 'CL', 'FA', 'CA', 'DI', 'DE', 'II', 'IE', 'SA', 'PA']
		ledgers.each do |type|
			ledgerHash[type] = getCashFlowAmt(from, to, type)
			subLedgerHash[type] = getSubLedgerAmount(from, to, type) if getLedgerTypeGrpHash[type].present?
			totalHash[type] = getCashFlowTotal(ledgerHash[type], subLedgerHash[type])
		end
		data = {ledgerHash: ledgerHash, subLedgerHash: subLedgerHash, totalHash: totalHash, ledgers: ledgers, from: from, to: to}
		data
  end

  def getSubLedgerAmount(from, to, ledgerType)
		subLedgerHash = Hash.new
		getLedgerTypeGrpHash[ledgerType].each do |subType|
			subLedgerHash[subType] = getCashFlowAmt(from, to, subType)  if !['BA', 'CS'].include? subType
		end
		subLedgerHash
  end

	def getCashFlowAmt(from, to, ledgerType)
		typeArr = ['c', 'd']
		detailHash = Hash.new
		typeArr.each do |type|
			other_type = type == 'c' ? 'd' : 'c'
			detailHash[type] = {}
			glTransaction = WkGlTransactionDetail.find_by_sql("SELECT sum(SL.amount) AS amount, SL.ledger_id FROM (
				SELECT DISTINCT GLD1.ledger_id, GLD1.id,GLD1.gl_transaction_id, GLD1.detail_type, GLD1.amount
				FROM wk_gl_transaction_details AS GLD1
				INNER JOIN wk_ledgers AS L1 ON L1.id = GLD1.ledger_id "+ get_comp_cond('L1') +"
				INNER JOIN wk_gl_transactions AS GLT1 ON GLT1.id = GLD1.gl_transaction_id "+ get_comp_cond('GLT1') +"
				LEFT JOIN wk_gl_transaction_details AS GLD2 ON GLD2.gl_transaction_id = GLD1.gl_transaction_id AND GLD2.detail_type = '#{other_type}' "+ get_comp_cond('GLD2') +"
				LEFT JOIN wk_ledgers AS L2 ON L2.id = GLD2.ledger_id "+ get_comp_cond('L2') +"
				LEFT JOIN wk_gl_transactions AS GLT2 ON GLT2.id = GLD2.gl_transaction_id "+ get_comp_cond('GLT2') +"
				WHERE GLD1.detail_type = '#{type}' and L1.ledger_type IN ('#{ledgerType}') and GLT1.trans_type IN ('R','P','PR','S')
				AND ((L2.ledger_type IN ('BA', 'CS') and GLT2.trans_type IN  ('PR','S')) OR GLT2.trans_type IN  ('R','P'))
				and GLT1.trans_date between '#{from}' and '#{to}' "+ get_comp_cond('GLD1') +"
			) AS SL
			GROUP BY SL.ledger_id")
			glTransaction.each{|entry| detailHash[type][entry.ledger_id] = entry.amount}
		end
		cashFlow = Hash.new
		ledgers = WkLedger.where(:ledger_type => ledgerType)
		ledgers.each do |ledger|
			key = ledger.name
			if detailHash['c'][ledger.id].present? || detailHash['d'][ledger.id].present?
				cashFlow[key] ||= Hash.new
				cashFlow[key]['inflow'] = detailHash['c'][ledger.id]
				cashFlow[key]['outflow'] = detailHash['d'][ledger.id]
			end
		end
		cashFlow
	end

	def getCashFlowTotal(mainHash, subHash)
		cashTotal = Hash.new
		inflow = 0
		outflow = 0
		cashTotals = {}
		(mainHash || {}).each do |ledger, entry|
			inflow += entry['inflow'] || 0
			outflow += entry['outflow'] || 0
		end
		(subHash || {}).each do |mainLedger, entry|
			(entry || {}).each do |subLedger, value|
				inflow += value['inflow'] || 0
				outflow += value['outflow'] || 0
			end
		end
		cashTotals['inflow'] = inflow
		cashTotals['outflow'] = outflow
		cashTotals
	end

	def getExportData(user_id, group_id, projID, from, to)
    reportData = calcReportData(user_id, group_id, projID, from, to)
    headers = {}
    data = []
		headers ={ledger_group: l(:label_particulars), ledger: '',subledger: '', inflow: l(:label_cash_inflow), outflow: l(:label_cash_outflow)}
    totalInflow = 0
    totalOutflow = 0
    reportData[:ledgers].each do |ledger|
      totalInflow += reportData[:totalHash][ledger]['inflow'] || 0
      totalOutflow += reportData[:totalHash][ledger]['outflow'] || 0
      if reportData[:totalHash][ledger]['inflow'] != 0 || reportData[:totalHash][ledger]['outflow'] != 0
		    data << {ledger_group: getSectionHeader(ledger), ledger: '', subledger: '', inflow:  reportData[:totalHash][ledger]['inflow'], outflow: reportData[:totalHash][ledger]['outflow']}
				renderLedgerAmount(data, reportData[:ledgerHash][ledger], 'mainledger')
				(reportData[:subLedgerHash][ledger] || {}).each do |subledger, subEntry|
					data << {ledger_group: '', ledger: getSectionHeader(subledger), subledger: '', inflow: '', outflow: ''} if subEntry.present?
					renderLedgerAmount(data, subEntry, 'subledger')
				end
      end
    end
		netInflow = totalInflow - totalOutflow
    data << {ledger_group: l(:label_total), ledger: '', subledger: '', inflow: totalInflow, outflow: totalOutflow }
    data << {ledger_group: l(:label_net_inflow), ledger: '', subledger: '', inflow: '', outflow: netInflow }
		return {data: data, headers: headers}
	end

	def renderLedgerAmount(data, entries, type)
		(entries || {}).each do |ledgername, entry|
			data << {ledger_group: '', ledger: type == 'mainledger' ? ledgername : '' , subledger: type == 'mainledger' ? '' : ledgername, inflow: entry["inflow"], outflow: entry["outflow"]}
		end
		data
	end

  def pdf_export(data)
    pdf = ITCPDF.new(current_language,'L')
    pdf.add_page
    row_Height = 8
    page_width    = pdf.get_page_width
    left_margin   = pdf.get_original_margins['left']
    right_margin  = pdf.get_original_margins['right']
    table_width = page_width - right_margin - left_margin
    width = table_width/data[:headers].length

    pdf.SetFontStyle('B', 10)
    pdf.RDMMultiCell(table_width, 5, data[:location], 0, 'C')
    pdf.RDMMultiCell(table_width, 5, l(:report_cash_flow), 0, 'C')
    pdf.RDMMultiCell(table_width, 5, data[:from].to_s+ " "+l(:label_date_to)+" "+ data[:to].to_s, 0, 'C')

		pdf.SetFontStyle('B', 9)
    pdf.set_fill_color(230, 230, 230)
		data[:headers].each{ |key, value| pdf.RDMCell(width, row_Height, value.to_s, 0, 0, '', 1) }
    pdf.ln
    pdf.set_fill_color(255, 255, 255)

    pdf.SetFontStyle('', 8)
		data[:data].each do |entry|
			entry.each do |key, value|
				[:ledger_group, :ledger].include?(key) ? pdf.SetFontStyle('B',9)  : pdf.SetFontStyle('',8)
        pdf.RDMCell(width, row_Height, value.to_s, 0, 0, '', 0)
      end
			pdf.ln
		end
    pdf.Output
  end
end