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

module ReportPf
	include WkreportHelper

	def calcReportData(userId, groupId, projId, from, to)
		from = from.to_date
    to = (from >> 1) - 1

		queryStr = " select U.id ,U.firstname, U.lastname , S.amount, WKU.retirement_account, S.salary_date from users U
									LEFT JOIN wk_users WKU ON WKU.user_id = U.id "+get_comp_cond('WKU')+"
									LEFT JOIN wk_salaries S ON S.user_id = U.id and  S.salary_date between '#{from}' and '#{to}' "+get_comp_cond('S')+"
									LEFT JOIN wk_salary_components SC ON SC.id = S.salary_component_id"+get_comp_cond('SC')
		sqlwhere = " where U.type = 'User' and (SC.component_type ='b' OR SC.component_type IS NULL) and (WKU.termination_date >= '#{from}' or (U.status = 1 and WKU.termination_date is null))
		"+get_comp_cond('U')
		if groupId.to_i > 0
			queryStr = queryStr + " LEFT JOIN groups_users GU on (GU.user_id = U.id )"
			sqlwhere = sqlwhere + " and GU.group_id =#{groupId}" if userId.to_i < 1
			sqlwhere = sqlwhere + " and GU.group_id =#{groupId} and U.id =#{userId}" if userId.to_i > 0
		elsif userId.to_i > 0
			sqlwhere = sqlwhere + " and U.id =#{userId}"
		end

    if !(validateERPPermission('A_TE_PRVLG') || User.current.admin?)
      sqlwhere = sqlwhere + " and U.id =#{User.current.id}"
    end

		salary_data = WkSalary.find_by_sql(queryStr + sqlwhere)
		pfData = getPFData(salary_data)
		salary_date = salary_data&.first&.salary_date.present? ? salary_data.first.salary_date : from
		tax = {data: pfData[:data], total: pfData[:total], from: salary_date.to_formatted_s(:long)}
		tax
	end

	def getPFData(salary_data)
		pf_data = {}
		total = {}
		total[:basicTot] = 0
		total[:wagesTot] = 0
		total[:eeTot] = 0
		total[:erTot] = 0
		total[:epsTot] = 0
		salary_data.each do |entry|
			key = entry.id
			pf_data[key] = {} if pf_data[key].blank?
			basic = entry.amount || 0
			wages = basic < 15000 ? basic : 15000
			emp_share = (basic * 0.12).round()
			eps_share = (wages * 0.0833).round()
			emr_share = (wages * 0.0367).round()
			total[:basicTot] += basic.round()
			total[:wagesTot] += wages.round()
			total[:eeTot] += emp_share
			total[:erTot] += emr_share
			total[:epsTot] += eps_share
			pf_data[key][:uan] = entry.retirement_account
			pf_data[key][:name] = entry.firstname.to_s + " "+entry.lastname.to_s
			pf_data[key][:basic] = basic.round()
			pf_data[key][:eps] = wages.round()
			pf_data[key][:ee] = emp_share
			pf_data[key][:eps_remitted] = eps_share
			pf_data[key][:er] = emr_share
		end
		return {data: pf_data, total: total}
	end

	def getExportData(user_id, group_id, projId, from, to)
    data = {headers: {}, data: []}
    reportData = calcReportData(user_id, group_id, projId, from, to)
    data[:headers] = {s_no: l(:label_attn_sl_no), uan: l(:label_uan), name: l(:field_name), wages1: l(:label_wages)+'-'+l(:label_basic), wages2: l(:label_wages)+'-'+l(:label_eps_wages), wages3: l(:label_wages)+'-'+l(:label_epf_wages), wages4: l(:label_wages)+'-'+l(:label_edli_wages), contribution_remitted1: 'CR-'+l(:label_ee_remitted), contribution_remitted2: 'CR-'+l(:label_eps_wages), contribution_remitted3: 'CR-'+l(:label_er_remitted)}
		total = reportData[:total]
		i = 1
    reportData[:data].each do |key, entry|
			index = {s_no: i}
      index.merge!({uan: entry[:uan], name: entry[:name], wages1: entry[:basic], wages2: entry[:eps], wages3: entry[:eps], wages4: entry[:eps], contribution_remitted1: entry[:ee], contribution_remitted2: entry[:eps_remitted], contribution_remitted3: entry[:er]})
			i+=1
			data[:data] << index
    end
    data[:data] << {s_no: '', uan: '', name: l(:label_total), wages1: total[:basicTot], wages2: total[:wagesTot], wages3: total[:wagesTot], wages4: total[:wagesTot], contribution_remitted1: total[:eeTot], contribution_remitted2: total[:epsTot], contribution_remitted3: total[:erTot]}
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
    pdf.RDMMultiCell(table_width, 5, l(:report_pf), 0, 'C')
    pdf.RDMMultiCell(table_width, 5, l(:label_wages_period)+": "+ data[:from].to_s, 0, 'C')

		logo =data[:logo]
		if logo.present?
			pdf.Image(logo.diskfile.to_s, page_width-50, 15, 30, 25)
		end
		pdf.ln(10)
    pdf.SetFontStyle('B', 8)
    pdf.set_fill_color(230, 230, 230)
    data[:headers].each{ |key, value| pdf.RDMCell(width, row_Height, value.to_s, 1, 0, 'C', 1) }
    pdf.ln
    pdf.set_fill_color(255, 255, 255)

    pdf.SetFontStyle('', 8)
    data[:data].each do |entry|
			entry.each{ |key, value|
				pdf.SetFontStyle('B', 8) if entry == data[:data].last
				pdf.RDMCell(width, row_Height, value.to_s, 1, 0, 'C', 1)
			}
    	pdf.ln
    end
    pdf.Output
  end
end