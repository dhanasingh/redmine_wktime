# Payment Gateway Transaction Model
# Tracks payment gateway requests and responses before creating actual WkPayment

class WkPgPayment < ApplicationRecord
  # Associations
  has_many :wk_pg_payment_items, dependent: :destroy
  belongs_to :wk_payment, optional: true
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true
  
  accepts_nested_attributes_for :wk_pg_payment_items

  # Validations
  validates :status, presence: true, length: { maximum: 5 }
  validates :pg_id, length: { maximum: 100 }, allow_blank: true
  validates :pg_pay_method, length: { maximum: 200 }, allow_blank: true
  validates :pg_msg, length: { maximum: 500 }, allow_blank: true
  validates :parent_type, presence: true
  validates :parent_id, presence: true

  # Status constants
  STATUS_INITIATED = 'IT'.freeze
  STATUS_SUCCESS = 'SU'.freeze
  STATUS_FAILURE = 'FA'.freeze
  STATUS_TIMEOUT = 'TE'.freeze
  STATUS_ABORTED = 'AB'.freeze

  # Scopes
  scope :initiated, -> { where(status: STATUS_INITIATED) }
  scope :successful, -> { where(status: STATUS_SUCCESS) }
  scope :failed, -> { where(status: [STATUS_FAILURE, STATUS_TIMEOUT, STATUS_ABORTED]) }
  scope :for_parent, ->(parent_type, parent_id) { where(parent_type: parent_type, parent_id: parent_id) }

  # Get the parent object (Account or Contact)
  def parent
    return nil unless parent_type.present? && parent_id.present?
    parent_type.constantize.find_by(id: parent_id)
  end

  # Check if payment is still pending (initiated but not timed out)
  def pending?
    status == STATUS_INITIATED
  end

  # Check if payment was successful
  def successful?
    status == STATUS_SUCCESS
  end

  # Mark as successful with gateway response
  def mark_success!(response_data = {})
    update!(
      status: STATUS_SUCCESS,
      pg_response: response_data.to_json
    )
  end

  # Mark as failed with error message
  def mark_failed!(message, response_data = {})
    update!(
      status: STATUS_FAILURE,
      pg_msg: message,
      pg_response: response_data.to_json
    )
  end

  # Mark as timed out
  def mark_timeout!
    update!(status: STATUS_TIMEOUT)
  end

  # Mark as aborted by user
  def mark_aborted!
    update!(status: STATUS_ABORTED)
  end
end
