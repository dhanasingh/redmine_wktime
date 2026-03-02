module ReportMoveInMoveOutByDate
  include RmresidentHelper
  include WkcrmHelper
  include WkcontactHelper

  def calcReportData(user_id, group_id, projId, from, to, location_id = nil)
    data = getData(from, to, projId, location_id)
    data[:from] = from.strftime("%d-%b-%Y")
    data[:to]   = to.strftime("%d-%b-%Y")
    data
  end

  def getExportData(user_id, group_id, projId, from, to, location_id = nil)
    reportData = calcReportData(user_id, group_id, projId, from, to, location_id)

    # Build structured sections matching the report view
    move_in_rows  = []
    move_out_rows = []

    serial = 0
    reportData[:move_in].each do |date, residents|
      residents.each do |r|
        serial += 1
        apt = [r[:apartment], ("#{l(:label_bed)} #{r[:bed]}" if r[:bed].present?)].compact.join(' - ')
        move_in_rows << {
          si_no:     serial,
          date:      date.to_s,
          location:  r[:location].presence || '—',
          resident:  r[:resident],
          apartment: apt.presence || '—'
        }
      end
    end

    serial = 0
    reportData[:move_out].each do |date, residents|
      residents.each do |r|
        serial += 1
        apt = [r[:apartment], ("#{l(:label_bed)} #{r[:bed]}" if r[:bed].present?)].compact.join(' - ')
        move_out_rows << {
          si_no:     serial,
          date:      date.to_s,
          location:  r[:location].presence || '—',
          resident:  r[:resident],
          apartment: apt.presence || '—',
          reason:    r[:reason].presence || '—'
        }
      end
    end

    {
      move_in_rows:  move_in_rows,
      move_out_rows: move_out_rows,
      from:          reportData[:from],
      to:            reportData[:to],
      customize:     true
    }
  end

  # -------------------------------------------------------
  # CSV export — two sections (Move-Ins / Move-Outs)
  # matching the report view layout
  # -------------------------------------------------------
  def csv_export(data)
    require 'csv'

    move_in_headers  = [
      l(:label_si_no),
      l(:label_move_in_date),
      l(:label_facility),
      l(:label_resident),
      l(:label_apartment)
    ]

    move_out_headers = [
      l(:label_si_no),
      l(:label_move_out_date),
      l(:label_facility),
      l(:label_resident),
      l(:label_apartment),
      l(:label_reason)
    ]

    CSV.generate do |csv|
      # ---- Title & date range ----
      csv << [l(:report_move_in_move_out_by_date)]
      csv << ["#{data[:from]} #{l(:label_date_to)} #{data[:to]}"]
      csv << []

      # ---- Move-Ins section ----
      csv << [l(:label_move_ins)]
      csv << move_in_headers

      if data[:move_in_rows].present?
        data[:move_in_rows].each do |r|
          csv << [r[:si_no], r[:date], r[:location], r[:resident], r[:apartment]]
        end
        csv << ['', '', l(:label_total_move_in), data[:move_in_rows].size]
      else
        csv << [l(:label_no_move_in_records)]
      end

      csv << []

      # ---- Move-Outs section ----
      csv << [l(:label_move_outs)]
      csv << move_out_headers

      if data[:move_out_rows].present?
        data[:move_out_rows].each do |r|
          csv << [r[:si_no], r[:date], r[:location], r[:resident], r[:apartment], r[:reason]]
        end
        csv << ['', '', l(:label_total_move_out), data[:move_out_rows].size]
      else
        csv << [l(:label_no_move_out_records)]
      end
    end
  end

  # -------------------------------------------------------
  # PDF export — mirrors report view exactly
  # -------------------------------------------------------
  def pdf_export(move_in_rows:, move_out_rows:, from:, to:, location: nil, logo: nil, **)
    pdf = ITCPDF.new(current_language, 'L')
    pdf.add_page

    row_height   = 7
    page_width   = pdf.get_page_width
    left_margin  = pdf.get_original_margins['left']
    right_margin = pdf.get_original_margins['right']
    table_width  = page_width - right_margin - left_margin

    if logo.present?
        pdf.Image(logo.diskfile.to_s, page_width - 50, 10, 30, 25)
    end

      pdf.SetFontStyle('B', 14)
      pdf.RDMMultiCell(table_width, 6, l(:report_move_in_move_out_by_date), 0, 'C')

      pdf.SetFontStyle('', 10)
      date_range = "#{from.respond_to?(:strftime) ? from.strftime('%d-%b-%Y') : from}" \
                  " #{l(:label_date_to)} " \
                  "#{to.respond_to?(:strftime) ? to.strftime('%d-%b-%Y') : to}"
      pdf.RDMMultiCell(table_width, 5, date_range, 0, 'C')
      pdf.ln(6)

      draw_section = lambda do |section_title, headers, col_widths, rows, total_label|
        pdf.SetFontStyle('B', 11)
        pdf.RDMMultiCell(table_width, 6, section_title, 0, 'C')
        pdf.ln(2)

        if rows.present?
          pdf.SetFontStyle('B', 8)
          pdf.set_fill_color(230, 230, 230)
          headers.each_with_index do |h, i|
            pdf.RDMCell(col_widths[i], row_height, h, 1, 0, 'C', 1)
          end
        pdf.ln

        pdf.SetFontStyle('', 8)
              pdf.set_fill_color(255, 255, 255)
              rows.each do |r|
                values = r.values
                values.each_with_index do |val, i|
                  pdf.RDMCell(col_widths[i], row_height, val.to_s, 1, 0, 'L', 0)
                end
          pdf.ln
        end

          total_col_count = col_widths.size
          pdf.set_fill_color(242, 242, 242)
          pdf.RDMCell(col_widths[0], row_height, '', 0, 0, 'C', 0)
          pdf.RDMCell(col_widths[1], row_height, '', 0, 0, 'C', 0)
          pdf.SetFontStyle('B', 8)
          pdf.RDMCell(col_widths[2], row_height, total_label, 1, 0, 'R', 1)
          pdf.RDMCell(col_widths[3], row_height, rows.size.to_s, 1, 0, 'L', 1)
          if total_col_count > 4
            (total_col_count - 4).times do |i|
              pdf.RDMCell(col_widths[4 + i], row_height, '', 0, 0, 'C', 0)
            end
          end
          pdf.ln
        else
          pdf.SetFontStyle('I', 9)
          no_records = section_title.include?(l(:label_move_ins)) ? l(:label_no_move_in_records) : l(:label_no_move_out_records)
          pdf.RDMMultiCell(table_width, 6, no_records, 0, 'L')
        end

        pdf.ln(6)
      end

      move_in_headers = [
        l(:label_si_no),
        l(:label_move_in_date),
        l(:label_facility),
        l(:label_resident),
        l(:label_apartment)
      ]
      tw = table_width.to_f
      mi_widths = [20, 45, 55, 60, tw - 20 - 45 - 55 - 60]

      draw_section.call(
        l(:label_move_ins),
        move_in_headers,
        mi_widths,
        move_in_rows,
        l(:label_total_move_in)
      )

      move_out_headers = [
        l(:label_si_no),
        l(:label_move_out_date),
        l(:label_facility),
        l(:label_resident),
        l(:label_apartment),
        l(:label_reason)
      ]
      mo_widths = [20, 45, 55, 55, tw - 20 - 45 - 55 - 55 - 40, 40]

      draw_section.call(
        l(:label_move_outs),
        move_out_headers,
        mo_widths,
        move_out_rows,
        l(:label_total_move_out)
      )

    pdf.Output
  end

  def getData(from, to, projId, locId = nil)
    from_date = from.to_date.beginning_of_day
    to_date   = to.to_date.end_of_day

    join_sql = <<-SQL
      LEFT JOIN wk_asset_properties ap
        ON ap.id = rm_residents.apartment_id
      LEFT JOIN wk_inventory_items ii
        ON ii.id = ap.inventory_item_id
      LEFT JOIN wk_locations loc
        ON loc.id = ii.location_id
      LEFT JOIN projects p
        ON p.id = ii.project_id
      LEFT JOIN wk_crm_enumerations reason_enum
        ON reason_enum.id = rm_residents.move_out_reason_id
    SQL

    residents_in = RmResident
      .where.not(move_in_date: nil)
      .where(move_in_date: from_date..to_date)
      .joins(join_sql)
      .select('rm_residents.*, p.name AS project_name, loc.name AS location_name')
      .order(:move_in_date)

    residents_out = RmResident
      .where.not(move_out_date: nil)
      .where(move_out_date: from_date..to_date)
      .joins(join_sql)
      .select('rm_residents.*, p.name AS project_name, loc.name AS location_name, reason_enum.name AS move_out_reason_name')
      .order(:move_out_date)

    if projId.present? && projId != '0'
      residents_in  = residents_in.where('p.id = ?', projId)
      residents_out = residents_out.where('p.id = ?', projId)
    end

    if locId.present? && locId != '0'
      residents_in  = residents_in.where('loc.id = ?', locId)
      residents_out = residents_out.where('loc.id = ?', locId)
    end

    move_ins = residents_in
      .group_by { |r| r.move_in_date.to_date }
      .transform_values do |residents|
        residents.map do |r|
          {
            date:      r.move_in_date.localtime.strftime("%Y-%m-%d %H:%M:%S"),
            resident:  resident_name(r),
            apartment: property_name(r.apartment_id),
            bed:       property_name(r.bed_id),
            project:   r.try(:project_name),
            location:  r.try(:location_name) || ''
          }
        end
      end

    move_outs = residents_out
      .group_by { |r| r.move_out_date.to_date }
      .transform_values do |residents|
        residents.map do |r|
          {
            date:      r.move_out_date.localtime.strftime("%Y-%m-%d %H:%M:%S"),
            resident:  resident_name(r),
            apartment: property_name(r.apartment_id),
            bed:       property_name(r.bed_id),
            project:   r.try(:project_name),
            location:  r.try(:location_name) || '',
            reason:    r.try(:move_out_reason_name).presence || '—'
          }
        end
      end

    {
      move_in:  move_ins,
      move_out: move_outs
    }
  end

  private

  def resident_name(resident)
    return '' unless resident&.resident_id.present?
    
    if resident.resident_type == "WkCrmContact"
      contact = WkCrmContact.find_by(id: resident.resident_id)
      return '' unless contact
      return [contact.last_name&.strip, contact.first_name&.strip].compact.join(', ')
    end
    
    if resident.resident_type == "WkAccount"
      account = WkAccount.find_by(id: resident.resident_id)
      return '' unless account
      return account.name.to_s
    end
    ''
  end

  def property_name(property_id)
    return '' unless property_id.present?
    prop = WkAssetProperty.find_by(id: property_id)
    prop&.name&.strip || "Property #{property_id}"
  end
end
