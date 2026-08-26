# ERPmine - ERP for service industry
# Copyright (C) 2011-  Adhi software pvt ltd
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

# Payment Gateway Payment Item Model
# Links invoices to a payment gateway transaction

class WkPgPaymentItem < ApplicationRecord
  # Associations
  belongs_to :wk_pg_payment
  belongs_to :wk_invoice, class_name: 'WkInvoice', foreign_key: 'invoice_id', optional: true
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true

  # Validations - Note: wk_pg_payment_id is set automatically via nested attributes
  validates :amount, presence: true, numericality: { greater_than: 0 }

  # Delegate invoice methods for convenience
  delegate :invoice_number, :invoice_date, to: :wk_invoice, allow_nil: true
end
