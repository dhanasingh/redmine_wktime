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

# Sage Business Cloud Accounting compatible CSV export format.
#
# Matches the native "Import journals" CSV template in Sage Business Cloud
# Accounting (Sage Accounting). Targets this product specifically because
# Sage 50 (US/CA) uses a different format (single signed Amount column and
# the GENERAL.CSV field set).
#
# Reference (Sage Business Cloud — Import journals):
#   https://gb-kb.sage.com/portal/app/portlets/results/
#     viewsolution.jsp?solutionid=222001000100916
#
# CSV columns (exact headers, in order):
#   Reference (required)         — groups lines of the same journal
#   Date (required)              — DD/MM/YYYY
#   Description (optional)
#   Nominal Code (required)
#   Details (optional)
#   Include on VAT/Tax Return? (optional) — 'Yes' or 'No'
#   Debit (required)             — positive amount or blank
#   Credit (required)            — positive amount or blank
#   Analysis Type 1-3 (optional)
#   Exchange Rate (optional)
#
# ERPmine to Sage mapping:
#   Transaction ID (ERPmine)    => Reference (groups journal lines)
#   trans_date                  => Date (DD/MM/YYYY)
#   comment                     => Description
#   ledger.id                   => Nominal Code (ERPmine has no code field;
#                                  the ID is a stable numeric identifier.
#                                  Users must align Sage nominal codes to
#                                  match, or map during import.)
#   ledger.name                 => Details (human-readable account label)
#   detail_type 'd' amount      => Debit
#   detail_type 'c' amount      => Credit

module AccountingExports
  class SageExport < Base

    def self.format_label
      I18n.t(:label_export_format_sage_business_cloud, default: 'Sage Business Cloud Accounting')
    end

    def self.format_description
      I18n.t(:label_export_desc_sage_business_cloud,
             default: 'Sage Business Cloud Accounting compatible CSV for journal import')
    end

    DATE_FORMAT = '%d/%m/%Y'

    TRANSACTION_HEADERS = ['Reference', 'Date', 'Description', 'Nominal Code',
                           'Details', 'Include on VAT/Tax Return?',
                           'Debit', 'Credit',
                           'Analysis Type 1', 'Analysis Type 2', 'Analysis Type 3',
                           'Exchange Rate'].freeze

    def generate_csv(transactions, trans_type_hash)
      build_csv do |csv|
        csv << csv_encode(TRANSACTION_HEADERS)

        transactions.each do |transaction|
          write_transaction_rows(csv, transaction)
        end
      end
    end

    def generate_ledger_csv(ledgers, ledger_type_hash)
      raise NotImplementedError, "Ledger export is not supported for Sage format"
    end

    private

    def write_transaction_rows(csv, transaction)
      details = transaction.transaction_details.includes(:ledger).order(:detail_type)

      debit_details = details.select { |d| d.detail_type == 'd' }
      credit_details = details.select { |d| d.detail_type == 'c' }
      ordered_details = debit_details + credit_details

      ordered_details.each do |detail|
        csv << csv_encode(build_row(transaction, detail))
      end
    end

    def build_row(transaction, detail)
      debit  = detail.detail_type == 'd' ? format_amount(detail.amount) : ''
      credit = detail.detail_type == 'c' ? format_amount(detail.amount) : ''

      [
        transaction.id.to_s,
        format_date(transaction.trans_date),
        transaction.comment.to_s,
        detail.ledger_id.to_s,
        detail.ledger.name,
        '',
        debit,
        credit,
        '', '', '',
        ''
      ]
    end

    def format_date(date)
      return '' if date.nil?
      date.strftime(DATE_FORMAT)
    end
  end
end
