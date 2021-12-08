# ERPmine - ERP for service industry
# Copyright (C) 2011-2021 Adhi software pvt ltd
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

require 'redmine/export/csv'
require 'redmine/export/pdf'

module ReportPayslip
	include WkpayrollHelper
  include WkreportHelper

	def calcReportData(userId, groupId, projId, from, to)
		minSalaryDate = WkSalary.where("salary_date between '#{from}' and '#{to}'").minimum(:salary_date)
		if minSalaryDate.blank?
			@wksalaryEntries = nil
		else
			getSalaryDetail(userId,minSalaryDate.to_date)
			@userYTDAmountHash = getYTDDetail(userId,minSalaryDate.to_date)
		end
		componentHash = Hash.new()
		if @wksalaryEntries.present?
			componentHash['b'] = Array.new
			componentHash['a'] = Array.new
			componentHash['d'] = Array.new
			@wksalaryEntries.each do |entry|
				componentHash[entry.component_type] = componentHash[entry.component_type].blank? ? [[entry.component_name,entry.amount,entry.currency,@userYTDAmountHash[entry.sc_component_id]]] :  componentHash[entry.component_type] << [entry.component_name,entry.amount,entry.currency,@userYTDAmountHash[entry.sc_component_id]]
			end
		end
		period = @financialPeriod || []
		componentHash['e'] = (componentHash['b'] || []) + (componentHash['a'] || [])
		salaryVal = {userDetail: @wksalaryEntries&.first, salData: componentHash, start: period[0]&.strftime("%B %d, %Y"), end: period[1]&.strftime("%B %d, %Y"), total: getTotal(componentHash)}
		salaryVal
	end

	def getTotal(componentHash)
		total = Hash.new
		total[:e] = 0
		total[:ye] = 0
		total[:d] = 0
		total[:yd] = 0
		total[:r] = 0
		total[:yr] = 0
		componentHash.each do |type, salaryVal|
			salaryVal.each do |value|
				total[:cur] = value[2]
				if(['a', 'b'].include?(type))
					total[:e] += value[1] || 0
					total[:ye] += value[3] || 0
				elsif(['d'].include?(type))
					total[:d] += value[1] || 0
					total[:yd] += value[3] || 0
				elsif(['r'].include?(type))
					total[:r] += value[1] || 0
					total[:yr] += value[3] || 0
				end
			end
		end
		total[:net] = total[:e] - total[:d]
		total[:netYTD] = total[:ye] - total[:yd]
		total[:reimburse] = total[:e] - total[:d] + total[:r]
		total[:reimburseYTD] = total[:ye] - total[:yd] + total[:yr]
		total
	end

	def getExportData(user_id, group_id, projID, from, to)
		user_id = User.current.id if user_id.to_i < 1
		resData = calcReportData(user_id, group_id, projID, from, to)
		detail = resData[:userDetail] || {}
		if resData[:userDetail].present?
			date = detail.present? ? (detail.salary_date-1)&.strftime("%B %Y") : nil
			data1 = {pay_period:[l(:label_pay_period), date], emp_name: [l(:label_emp_name), detail&.user&.name],
				employee_id: [l(:label_employee_id), detail&.id1], join_date: [l(:field_join_date), detail&.join_date]}
			data2 = {title1: [l(:label_earning), l(:label_deduction)], title2: [l(:label_monthly), l(:label_ytd), l(:label_monthly), l(:label_ytd)]}
			data3 = {title1: [l(:label_reimbursements)], title2: [l(:label_monthly), l(:label_ytd)]}

			(resData[:salData] || []).each do |entry|
				if ["b", "a",].include? entry.first
					setData(data2, entry, "row1")
				elsif ["d"].include? entry.first
					setData(data2, entry, "row2")
				elsif ["r"].include? entry.first
					setData(data3, entry, "row")
				end
			end
			return {data1: data1, data2: data2, data3: data3, options: {start: resData[:start], end: resData[:end]}, customize: true}
		else
			return {customize: true}
		end
	end

	def setData(data, entry, key="row")
		data[key] ||= []
		(entry.last || []).map do |row|
			data[key] << {label: row.first, value1: row[1], value2: row.last, currency: row[2]}
		end
	end

	def csv_export(data)
		Redmine::Export::CSV.generate(:encoding => l(:general_csv_encoding)) do |csv|
			csv << [l(:report_payslip)]
			csv << []
			if data[:data1].present?
				row = []
				totalRow1Col1 = 0
				totalRow1Col2 = 0
				curRow1 = nil
				totalRow2Col1 = 0
				totalRow2Col2 = 0
				curRow2 = nil
				totalCol1 = 0
				totalCol2 = 0
				curCol = nil
				(data[:data1] || {}).each do |key, value|
					row += [value&.first&.to_s, value&.last&.to_s] if value.present?
				end
				csv << (row)
				csv << []

				csv << [data[:data2][:title1].first, "", "", data[:data2][:title1].last]
				csv << ["", data[:data2][:title2].first, data[:data2][:title2].last, "", data[:data2][:title2].first, data[:data2][:title2].last]
				len = (data[:data2]["row1"] || []).length > (data[:data2]["row2"] || []).length ? (data[:data2]["row1"] || []).length : (data[:data2]["row2"] || []).length
				(0..(len-1)).each do |index|
					row1 = data[:data2]["row1"] && data[:data2]["row1"][index] && data[:data2]["row1"][index] || {}
					row2 = data[:data2]["row2"] && data[:data2]["row2"][index] && data[:data2]["row2"][index] || {}
					totalRow1Col1 += row1[:value1].to_f
					totalRow1Col2 += row1[:value2].to_f
					curRow1 = row1[:currency]
					totalRow2Col1 += row2[:value1].to_f
					totalRow2Col2 += row2[:value2].to_f
					curRow2 = row1[:currency]
					csv << [row1[:label].to_s, row1[:currency].to_s+ " " +row1[:value1].to_s, row1[:currency].to_s+ " " +row1[:value2].to_s, row2[:label].to_s, row2[:currency].to_s+ " " +row2[:value1].to_s, row2[:currency].to_s+ " " +row2[:value2].to_s]
				end
				csv << [l(:label_total_earning), curRow1+ " " +totalRow1Col1.to_s, curRow1+ " " +totalRow1Col2.to_s, l(:label_total_deduction), curRow2+ " " +totalRow2Col1.to_s, curRow2+ " " +totalRow2Col2.to_s]
				csv << [l(:label_net_earning), curRow1+ " " +(totalRow1Col1 - totalRow2Col1).to_s, curRow2+ " " +(totalRow1Col2 - totalRow2Col2).to_s]
				csv << []

				csv << [data[:data3][:title1].first]
				csv << ["", data[:data3][:title2].first, data[:data3][:title2].last]
				len = (data[:data3]["row"] || []).length - 1
				(0..len).each do |index|
					row = data[:data3]["row"] && data[:data3]["row"][index] && data[:data3]["row"][index] || {}
					totalCol1 += row[:value1].to_f
					totalCol2 += row[:value2].to_f
					curCol = row[:currency]
					csv << [row[:label], row[:currency]+ " " +row[:value1].to_s, row[:currency]+ " " +row[:value2].to_s]
				end
				csv << [l(:label_net_earning) + " + "+ l(:label_reimbursements), curCol+ " " +((totalRow1Col1 - totalRow2Col1) + totalCol1).to_s, curCol+ " " +((totalRow1Col2 - totalRow2Col2) + totalCol2).to_s]
				csv << []
				csv << [l(:label_ytd_description, start:  data[:options][:start], end: data[:options][:end])]
			else
				csv << [l(:label_no_data)]
			end
		end
	end

	def pdf_export(data={})
		pdf = Redmine::Export::PDF::ITCPDF.new(current_language)
		pdf.set_title(l(:report_payslip))
		pdf.alias_nb_pages
		pdf.add_page
		rHeight = 6
		pWidth = pdf.get_page_width
		lMargin = pdf.get_original_margins['left']
		rMargin = pdf.get_original_margins['right']
		tWidth = pWidth - rMargin - lMargin
		pdf.SetFontStyle('B', 11)
		pdf.RDMMultiCell(tWidth, rHeight, l(:report_payslip), 0, 'C')
		pdf.ln(rHeight)

		pdf.RDMMultiCell(tWidth, rHeight, getMainLocation || " ", 0, 'L')
		pdf.SetFontStyle('', 9)
		pdf.RDMMultiCell(tWidth, rHeight, getAddress || " ", 0, 'L')
		#logo
		pdf.Image(data[:logo].diskfile.to_s, pWidth-50, 15, 30, 25) if data[:logo].present?
		pdf.set_image_scale(1.6)
		pdf.ln(rHeight)

		if data[:data1].present?
			totalRow1Col1 = 0
			totalRow1Col2 = 0
			curRow1 = nil
			totalRow2Col1 = 0
			totalRow2Col2 = 0
			curRow2 = nil
			totalCol1 = 0
			totalCol2 = 0
			curCol = nil
			(data[:data1] || {}).each do |key, value|
				if value.present?
					setHeader(pdf)
					pdf.RDMMultiCell(tWidth/8, rHeight*1.5, value&.first&.to_s || " ", 1, "L", 1, 0)
					setRow(pdf)
					pdf.RDMMultiCell(tWidth/8, rHeight*1.5, value&.last&.to_s || " ", 1, "L", 1, 0)
				end
			end
			pdf.ln(rHeight*1.5)
			pdf.ln(4)

			setHeader(pdf)
			pdf.RDMMultiCell(tWidth/2, rHeight, data[:data2][:title1].first || " ", 1, "C", 1, 0)
			pdf.RDMMultiCell(tWidth/2, rHeight, data[:data2][:title1].last || " ", 1, "C", 1, 0)
			pdf.ln(rHeight)
			pdf.RDMMultiCell(tWidth/6, rHeight, "", 1, "C", 1, 0)
			pdf.RDMMultiCell(tWidth/6, rHeight, data[:data2][:title2].first || " ", 1, "C", 1, 0)
			pdf.RDMMultiCell(tWidth/6, rHeight, data[:data2][:title2].last || " ", 1, "C", 1, 0)
			pdf.RDMMultiCell(tWidth/6, rHeight, "", 1, "C", 1, 0)
			pdf.RDMMultiCell(tWidth/6, rHeight, data[:data2][:title2].first || " ", 1, "C", 1, 0)
			pdf.RDMMultiCell(tWidth/6, rHeight, data[:data2][:title2].last || " ", 1, "C", 1, 0)
			pdf.ln(rHeight)
			setRow(pdf)

			len = (data[:data2]["row1"] || []).length > (data[:data2]["row2"] || []).length ? (data[:data2]["row1"] || []).length : (data[:data2]["row2"] || []).length
			(0..(len-1)).each do |index|
				row1 = data[:data2]["row1"] && data[:data2]["row1"][index] && data[:data2]["row1"][index] || {}
				row2 = data[:data2]["row2"] && data[:data2]["row2"][index] && data[:data2]["row2"][index] || {}
				totalRow1Col1 += row1[:value1].to_f
				totalRow1Col2 += row1[:value2].to_f
				curRow1 = row1[:currency]
				totalRow2Col1 += row2[:value1].to_f
				totalRow2Col2 += row2[:value2].to_f
				curRow2 = row2[:currency]
				pdf.SetFontStyle('B', 9)
				pdf.RDMMultiCell(tWidth/6, rHeight, row1[:label] || " ", 1, "L", 1, 0)
				pdf.SetFontStyle('', 9)
				pdf.RDMMultiCell(tWidth/6, rHeight, row1[:currency].to_s+ " " +row1[:value1].to_s, 1, "R", 1, 0)
				pdf.RDMMultiCell(tWidth/6, rHeight, row1[:currency].to_s+ " " +row1[:value2].to_s, 1, "R", 1, 0)
				pdf.SetFontStyle('B', 9)
				pdf.RDMMultiCell(tWidth/6, rHeight, row2[:label] || " ", 1, "L", 1, 0)
				pdf.SetFontStyle('', 9)
				pdf.RDMMultiCell(tWidth/6, rHeight, row2[:currency].to_s+ " " +row2[:value1].to_s, 1, "R", 1, 0)
				pdf.RDMMultiCell(tWidth/6, rHeight, row2[:currency].to_s+ " " +row2[:value2].to_s, 1, "R", 1, 0)
				pdf.ln(rHeight)
			end
			setHeader(pdf)
			pdf.RDMMultiCell(tWidth/6, rHeight, l(:label_total_earning), 1, "L", 1, 0)
			setRow(pdf)
			pdf.RDMMultiCell(tWidth/6, rHeight, curRow1.to_s+ " " +totalRow1Col1.to_s, 1, "R", 1, 0)
			pdf.RDMMultiCell(tWidth/6, rHeight, curRow1.to_s+ " " +totalRow1Col2.to_s, 1, "R", 1, 0)
			setHeader(pdf)
			pdf.RDMMultiCell(tWidth/6, rHeight, l(:label_total_deduction), 1, "L", 1, 0)
			setRow(pdf)
			pdf.RDMMultiCell(tWidth/6, rHeight, curRow2.to_s+ " " +totalRow2Col1.to_s, 1, "R", 1, 0)
			pdf.RDMMultiCell(tWidth/6, rHeight, curRow2.to_s+ " " +totalRow2Col2.to_s, 1, "R", 1, 0)
			pdf.ln(rHeight)
			setHeader(pdf)
			pdf.RDMMultiCell(tWidth/6, rHeight, l(:label_net_earning), 1, "L", 1, 0)
			setRow(pdf)
			pdf.RDMMultiCell(tWidth/6, rHeight, curRow1.to_s+ " " +(totalRow1Col1 - totalRow2Col1).to_s, 1, "R", 1, 0)
			pdf.RDMMultiCell(tWidth/6, rHeight, curRow1.to_s+ " " +(totalRow1Col2 - totalRow2Col2).to_s, 1, "R", 1, 0)
			pdf.ln(rHeight)
			pdf.ln(4)

			setHeader(pdf)
			pdf.RDMMultiCell((tWidth/4)*3, rHeight, data[:data3][:title1].first || " ", 1, "C", 1, 0)
			pdf.ln(rHeight)
			pdf.RDMMultiCell(tWidth/4, rHeight, "", 1, "C", 1, 0)
			pdf.RDMMultiCell(tWidth/4, rHeight, data[:data3][:title2].first || " ", 1, "C", 1, 0)
			pdf.RDMMultiCell(tWidth/4, rHeight, data[:data3][:title2].last || " ", 1, "C", 1, 0)
			pdf.ln(rHeight)
			setRow(pdf)
			len = (data[:data3]["row"] || []).length - 1
			(0..len).each do |index|
				row = data[:data3]["row"] && data[:data3]["row"][index] && data[:data3]["row"][index] || {}
				totalCol1 += row[:value1].to_f
				totalCol2 += row[:value2].to_f
				curCol = row[:currency]
				pdf.SetFontStyle('B', 9)
				pdf.RDMMultiCell(tWidth/4, rHeight, row[:label] || " ", 1, "L", 1, 0)
				pdf.SetFontStyle('', 9)
				pdf.RDMMultiCell(tWidth/4, rHeight, row[:currency].to_s+ " " +row[:value1].to_s, 1, "R", 1, 0)
				pdf.RDMMultiCell(tWidth/4, rHeight, row[:currency].to_s+ " " +row[:value2].to_s, 1, "R", 1, 0)
				pdf.ln(rHeight)
			end
			setHeader(pdf)
			pdf.RDMMultiCell(tWidth/4, rHeight, l(:label_net_earning) + ' + '+ l(:label_reimbursements), 1, "L", 1, 0)
			setRow(pdf)
			pdf.RDMMultiCell(tWidth/4, rHeight, curCol.to_s+" "+((totalRow1Col1 - totalRow2Col1) + totalCol1).to_s, 1, "R", 1, 0)
			pdf.RDMMultiCell(tWidth/4, rHeight, curCol.to_s+" "+((totalRow1Col2 - totalRow2Col2) + totalCol2).to_s, 1, "R", 1, 1)
			pdf.ln(rHeight)
			pdf.RDMMultiCell(tWidth, rHeight, l(:label_ytd_description, start:  data[:options][:start], end: data[:options][:end]), 0, "L", 1, 0)
		else
			setRow(pdf)
			pdf.RDMMultiCell(tWidth, rHeight, l(:label_no_data), 0, "L", 1, 1)
		end
		pdf.Output
	end

	def setHeader(pdf)
		pdf.SetFontStyle('B',8)
		pdf.SetFillColor(230, 230, 230)
	end

	def setRow(pdf)
		pdf.SetFontStyle('',8)
		pdf.SetFillColor(255, 255, 255)
	end
end