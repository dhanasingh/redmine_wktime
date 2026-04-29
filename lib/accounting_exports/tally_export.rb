# ERPmine - ERP for service industry
# Copyright (C) 2011-2024  Adhi software pvt ltd
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

# Tally-compatible CSV export format.
#
# Generates CSV with ledger entries as rows, matching Tally's import format:
#   - First row of each transaction: Date, Voucher Type, Invoice Number, Narration + first debit ledger
#   - Subsequent rows: remaining ledger entries (credit entries)
#
# Tally mapping:
#   Transaction No (ERPmine) => Invoice Number (Tally)
#   Comment (ERPmine)        => Narration (Tally)
#
# Supports:
#   - One debit / one credit ledger per transaction
#   - Multiple debit rows / one credit ledger per transaction

module AccountingExports
  class TallyExport < Base

    def self.format_label
      I18n.t(:label_export_format_tally_prime, default: 'Tally Prime')
    end

    def self.format_description
      I18n.t(:label_export_desc_tally_prime,
             default: 'Tally-compatible CSV with ledger entries for import into Tally Prime')
    end

    DATE_FORMAT = '%d/%b/%Y'
    DETAIL_TYPE_MAP = { 'd' => 'Dr', 'c' => 'Cr' }.freeze

    TRANSACTION_HEADERS = ['Voucher Date', 'Voucher Type Name', 'Voucher Number',
                           'Narration', 'Ledger Name', 'Ledger Amount',
                           'Ledger Amount Dr/Cr'].freeze

    LEDGER_HEADERS = ['Name', 'Group Name', 'Ledger - Opening Balance',
                      'Ledger Opening Balance - Dr/Cr'].freeze

    def generate_csv(transactions, trans_type_hash)
      build_csv do |csv|
        csv << csv_encode(TRANSACTION_HEADERS)

        transactions.each do |transaction|
          write_transaction_rows(csv, transaction, trans_type_hash)
        end
      end
    end

    def generate_ledger_csv(ledgers, ledger_type_hash)
      build_csv do |csv|
        csv << csv_encode(LEDGER_HEADERS)

        ledgers.each do |ledger|
          balance = ledger.opening_balance || 0
          dr_cr = balance >= 0 ? 'Dr' : 'Cr'
          csv << csv_encode([
            ledger.name,
            ledger_type_hash[ledger.ledger_type] || ledger.ledger_type,
            format_amount(balance.abs),
            dr_cr
          ])
        end
      end
    end

    private

    def write_transaction_rows(csv, transaction, trans_type_hash)
      details = transaction.transaction_details.includes(:ledger).order(:detail_type)

      debit_details = details.select { |d| d.detail_type == 'd' }
      credit_details = details.select { |d| d.detail_type == 'c' }
      ordered_details = debit_details + credit_details

      first_row = true

      ordered_details.each do |detail|
        csv << csv_encode(build_row(transaction, detail, first_row, trans_type_hash))
        first_row = false
      end
    end

    def build_row(transaction, detail, is_first_row, trans_type_hash)
      row = []

      if is_first_row
        row << format_date(transaction.trans_date)
        row << (trans_type_hash[transaction.trans_type] || transaction.trans_type)
        row << transaction.id.to_s
        row << transaction.comment.to_s
      else
        row << '' << '' << '' << ''
      end

      row << detail.ledger.name
      row << format_amount(detail.amount)
      row << (DETAIL_TYPE_MAP[detail.detail_type] || detail.detail_type)

      row
    end

    def format_date(date)
      return '' if date.nil?
      date.strftime(DATE_FORMAT)
    end
  end
end
