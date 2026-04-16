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

# Base class for all export formats.
#
# To add a new export format (e.g. QuickBooks, Indian Income Tax):
#   1. Create a new file in lib/accounting_exports/ (e.g. quickbooks.rb)
#   2. Define a class inheriting from AccountingExports::Base
#   3. Implement #generate_csv
#   4. The format will automatically appear in the export dropdown
#
# Example:
#   class AccountingExports::Quickbooks < AccountingExports::Base
#     def generate_csv(transactions, trans_type_hash)
#       build_csv do |csv|
#         csv << csv_encode(['Date', 'Account', 'Amount', ...])
#         transactions.each { |txn| ... }
#       end
#     end
#   end
#
# Class name determines format_name, format_label, and file_name automatically:
#   TallyLedgerEntries => name: 'tally_ledger_entries', label: 'Tally Ledger Entries'

module AccountingExports
  class Base

    # --- Discovery & lookup ---

    def self.available_formats
      descendants.map(&:to_hash)
    end

    def self.find_format(format_name)
      klass = descendants.find { |k| k.format_name == format_name }
      raise "Export format not found: #{format_name}" unless klass
      klass.new
    end

    # --- Class methods (auto-derived from class name) ---

    def self.format_name
      name.demodulize.underscore
    end

    def self.format_label
      name.demodulize.underscore.titleize
    end

    def self.format_description
      ''
    end

    def self.file_name
      format_name
    end

    def self.to_hash
      {
        'name'        => format_name,
        'label'       => format_label,
        'description' => format_description,
        'file_name'   => file_name
      }
    end

    # --- Instance methods ---

    def generate_csv(transactions, trans_type_hash)
      raise NotImplementedError, "#{self.class.name} must implement #generate_csv"
    end

    def generate_ledger_csv(ledgers, ledger_type_hash)
      raise NotImplementedError, "#{self.class.name} must implement #generate_ledger_csv"
    end

    def output_file_name
      self.class.file_name + '.csv'
    end

    private

    def csv_encoding
      encoding = 'UTF-8'
      begin
        encoding = I18n.t(:general_csv_encoding) if defined?(I18n)
      rescue
      end
      encoding
    end

    def csv_encode(values)
      enc = csv_encoding
      values.collect { |v| Redmine::CodesetUtil.from_utf8(v.to_s, enc) }
    rescue
      values.collect(&:to_s)
    end

    def build_csv(&block)
      Redmine::Export::CSV.generate(&block)
    end

    def format_amount(value, fmt = "%.2f")
      return '' if value.nil?
      fmt % value
    end
  end
end

# Load all format files in this directory so they register as descendants
Dir.glob(File.join(File.dirname(__FILE__), '*.rb')).each do |file|
  require file unless File.basename(file) == 'base.rb'
end
