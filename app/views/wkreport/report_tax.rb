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

module ReportTax
	include WkreportHelper

	def calcReportData(userId, groupId, projId, from, to)
		from = from.to_date
		to = to.to_date
		betwn_mnth_count = getInBtwMonthsArr(from, to)

		if betwn_mnth_count.length > 12
			from = Date.civil(to.year,to.month, 1) - 11.month
			to = Date.civil((to + 1.month).year,(to + 1.month).month, 1) - 1
		end

		inBtwMonths = getInBtwMonthsArr(from, to)
		userSqlStr = getUserQueryStr(groupId, userId, from)
		userSqlStr += " order by employee_id"
		userList = User.find_by_sql(userSqlStr)

		queryStr = getQueryStr +
				"left join groups_users gu on (gu.user_id = u.id and gu.group_id = #{groupId}) " +
				"where u.type = 'User' and component_type != 'c'  and (wu.termination_date >= '#{from}' or (u.status = #{User::STATUS_ACTIVE} and wu.termination_date is null))"+get_comp_cond('s')
		if groupId.to_i > 0 && userId.to_i < 1
			queryStr = queryStr + " and gu.group_id is not null"
		elsif userId.to_i > 0
			queryStr = queryStr + " and s.user_id = #{userId}"
		end

		queryStr = queryStr + " and s.salary_date  between '#{from}' and '#{to}' "

		if !(validateERPPermission('A_TE_PRVLG') || User.current.admin?)
			queryStr = queryStr + " and u.id = #{User.current.id} "
		end

		queryStr = queryStr + " order by s.user_id"
		salary_data = WkSalary.find_by_sql(queryStr)
		taxData = getTaxData(salary_data, userList, inBtwMonths)
		tax = {taxData: taxData, from: from.to_formatted_s(:long), to: to.to_formatted_s(:long)}
		tax
	end

	def getTaxData(salary_data, userList, inBtwMonths)
		tds_id = WkSetting.where("name = 'income_tax'").first
		taxData = {}
		tdsHash = {}
		grossHash = {}
		inBtwMonths.each do |month|
			key = (month.first).to_s  + "_"  + (month.last).to_s
			taxData[key] = {}
			taxData[key]['users'] = []
			tdsHash[key] = {}
			grossHash[key] = {}
			grossTot = cessTot = tdsTot = total = 0
			userList.each do |user|
				user_id = user.id.to_s
				tdsHash[key][user_id] = 0
				grossHash[key][user_id] = 0
				salary_data.each do |entry|
					sal_key = entry.salary_date.strftime("%Y") + "_" + entry.salary_date.strftime("%-m")
					if (entry.component_type == 'b' || entry.component_type == 'a') && user.id == entry.user_id && sal_key == key
						grossHash[key][user_id] = entry.amount + grossHash[key][user_id]
					end
					if tds_id.value.to_i == entry.sc_component_id && user.id == entry.user_id && sal_key == key
						tdsHash[key][user_id] = entry.amount
					end
				end
				if tdsHash[key][user_id] > 0
					tds = cess = 0
					tds = (tdsHash[key][user_id]/1.04).round() if tdsHash[key][user_id].present?
					cess =  (tdsHash[key][user_id] - tds) if tdsHash[key][user_id].present?
					grossTot += grossHash[key][user_id]
					total += tdsHash[key][user_id]
					cessTot += cess
					tdsTot += tds
					taxData[key]['users'] << {employee_id: user.employee_id, tax_id: decrypt_values(user.tax_id), name: user.name, gross: grossHash[key][user_id], tds: tds, cess: cess, taxTotal: tdsHash[key][user_id]}
				end
			end
			taxData[key]['grossTot'] =  grossTot
			taxData[key]['cessTot'] =  cessTot
			taxData[key]['tdsTot'] =  tdsTot
			taxData[key]['total'] =  total
			taxData[key]['month_name'] =  Date::MONTHNAMES[month.last].to_s + " " + month.first.to_s
		end
		taxData
	end

	def getExportData(user_id, group_id, projId, from, to)
    data = {headers: {}, data: []}
    reportData = calcReportData(user_id, group_id, projId, from, to)
		reportData[:taxData].each do |mnth, val|
			data[:headers] = {mnth: '', employee_id: l(:label_employee_id), tax: l(:field_tax), user_name: l(:label_user_name), gross: l(:label_gross), tds: l(:label_tds), cess: l(:label_cess), total: l(:label_total)}
			data[:data] << {mnth: val['month_name'], employee_id: '', tax: '', total: '', gross: '', tds: '', cess: '', alltotal: ''}
			val['users'].each do |entry|
				data[:data] <<  {mnth: '', employee_id: entry[:employee_id], tax: entry[:tax_id], user_name: entry[:name], gross: entry[:gross], tds: entry[:tds], cess: entry[:cess], total: entry[:taxTotal]}
			end
			data[:data] << {mnth: '', employee_id: '', tax: '', total: l(:label_total), gross: val['grossTot'], tds: val['tdsTot'], cess: val['cessTot'], alltotal: val['total']}
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

    pdf.SetFontStyle('B', 13)
    pdf.RDMMultiCell(table_width, 5, data[:location], 0, 'C')
    pdf.RDMMultiCell(table_width, 5, l(:report_tax), 0, 'C')
		pdf.RDMMultiCell(table_width, 5, data[:from].to_s+' '+l(:label_date_to)+' '+data[:to].to_s, 0, 'C')
		logo =data[:logo]
		if logo.present?
			pdf.Image(logo.diskfile.to_s, page_width-50, 15, 30, 25)
		end
		pdf.ln()
    pdf.SetFontStyle('B', 8)
    pdf.set_fill_color(230, 230, 230)
    data[:headers].each{ |key, value| pdf.RDMCell(width, row_Height, value.to_s, 1, 0, 'C', 1) }
    pdf.ln
    pdf.set_fill_color(255, 255, 255)

    pdf.SetFontStyle('', 8)
    data[:data].each do |entry|
			entry.each{ |key, value|
				pdf.RDMCell(width, row_Height, value.to_s, 1, 0, 'C', 1)
			}
    	pdf.ln
    end
    pdf.Output
  end
end