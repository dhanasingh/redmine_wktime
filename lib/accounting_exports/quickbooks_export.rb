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

# QuickBooks Online compatible CSV export format.
#
# Matches the native QuickBooks Online journal entry CSV import template
# (Intuit sample template). Header names use the exact wording QBO expects
# so the import wizard auto-maps columns.
#
# Reference:
#   https://quickbooks.intuit.com/learn-support/en-us/help-article/
#     import-export-data-files/import-journal-entries-quickbooks-online/
#     L4tQBwbs7_US_en_US
#
# Required: Journal No., Journal Date, Account Name, Debits, Credits
# Optional: Description, Memo, Name, Location, Class, Currency
# Date: MM/DD/YYYY. Max 1000 lines per file.
#
# ERPmine to QuickBooks mapping:
#   Transaction ID           => Journal No.
#   trans_date               => Journal Date
#   comment                  => Memo (entry-level) and Description (line-level)
#   ledger.name              => Account Name
#   detail_type 'd' amount   => Debits
#   detail_type 'c' amount   => Credits
#   detail.currency          => Currency

module AccountingExports
  class QuickbooksExport < Base

    def self.format_label
      I18n.t(:label_export_format_quickbooks_online, default: 'QuickBooks Online')
    end

    def self.format_description
      I18n.t(:label_export_desc_quickbooks_online,
             default: 'QuickBooks Online compatible CSV for journal entry import')
    end

    DATE_FORMAT = '%m/%d/%Y'

    TRANSACTION_HEADERS = ['Journal No.', 'Journal Date', 'Account Name',
                           'Debits', 'Credits', 'Description', 'Memo',
                           'Name', 'Location', 'Class', 'Currency'].freeze

    def generate_csv(transactions, trans_type_hash)
      build_csv do |csv|
        csv << csv_encode(TRANSACTION_HEADERS)

        transactions.each do |transaction|
          write_transaction_rows(csv, transaction)
        end
      end
    end

    def generate_ledger_csv(ledgers, ledger_type_hash)
      raise NotImplementedError, "Ledger export is not supported for QuickBooks format"
    end

    private

    def write_transaction_rows(csv, transaction)
      details = transaction.transaction_details.includes(:ledger).order(:detail_type)

      debit_details = details.select { |d| d.detail_type == 'd' }
      credit_details = details.select { |d| d.detail_type == 'c' }
      ordered_details = debit_details + credit_details

      first_row = true

      ordered_details.each do |detail|
        csv << csv_encode(build_row(transaction, detail, first_row))
        first_row = false
      end
    end

    def build_row(transaction, detail, is_first_row)
      debit = detail.detail_type == 'd' ? format_amount(detail.amount) : ''
      credit = detail.detail_type == 'c' ? format_amount(detail.amount) : ''

      [
        is_first_row ? transaction.id.to_s : '',
        is_first_row ? format_date(transaction.trans_date) : '',
        detail.ledger.name,
        debit,
        credit,
        transaction.comment.to_s,
        is_first_row ? transaction.comment.to_s : '',
        '',
        '',
        '',
        detail.currency.to_s
      ]
    end

    def format_date(date)
      return '' if date.nil?
      date.strftime(DATE_FORMAT)
    end
  end
end
