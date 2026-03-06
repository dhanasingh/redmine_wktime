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
