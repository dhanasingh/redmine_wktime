# Payment Gateway Helper Module
# Provides utility methods for payment gateway operations

module WkpgHelper
  # Currency code mapping
  CURRENCY_MAP = {
    '₹' => 'INR',
    'Rs' => 'INR',
    'Rs.' => 'INR',
    'INR' => 'INR',
    '$' => 'USD',
    'USD' => 'USD',
    '€' => 'EUR',
    'EUR' => 'EUR',
    '£' => 'GBP',
    'GBP' => 'GBP'
  }.freeze

  # Gateway types
  GATEWAY_CCAVENUE = 'CCAVENUE'.freeze
  GATEWAY_PAYPAL = 'PAYPAL'.freeze

  # Status labels for display
  def pg_status_label(status)
    status_map = {
      'IT' => l(:label_initiated),
      'SU' => l(:label_success),
      'FA' => l(:label_failure),
      'TE' => l(:label_timeout),
      'AB' => l(:label_aborted)
    }
    status_map[status] || status
  end

  # Convert currency symbol to ISO code
  def get_currency_code(currency)
    return 'INR' if currency.blank?
    CURRENCY_MAP[currency.to_s.strip] || currency.to_s.upcase
  end

  # Determine gateway type based on currency
  def get_gateway_type(currency)
    code = get_currency_code(currency)
    case code
    when 'INR'
      GATEWAY_CCAVENUE
    else
      GATEWAY_PAYPAL
    end
  end

  # Get payment gateway link based on currency
  def get_pg_link(currency, invoice_ids = nil)
    gateway_type = get_gateway_type(currency)
    
    case gateway_type
    when GATEWAY_CCAVENUE
      url_for(controller: 'wkpg_ccavenue', action: 'process_payment', invoice_ids: invoice_ids)
    when GATEWAY_PAYPAL
      url_for(controller: 'wkpg_paypal', action: 'process_payment', invoice_ids: invoice_ids)
    else
      # Default to CCAvenue
      url_for(controller: 'wkpg_ccavenue', action: 'process_payment', invoice_ids: invoice_ids)
    end
  end

  # Get payment gateway timeout from settings (in minutes)
  def get_pg_timeout
    settings = Setting.plugin_redmine_wktime
    timeout = settings['wktime_pg_timeout'].to_i
    timeout > 0 ? timeout : 15  # Default 15 minutes
  end

  # Get payment status constant from gateway response
  def get_payment_status(status)
    status_map = {
      'Success' => 'SU',
      'COMPLETED' => 'SU',
      'Failure' => 'FA',
      'FAILED' => 'FA',
      'Aborted' => 'AB',
      'CANCELLED' => 'AB',
      'Timeout' => 'TE'
    }
    status_map[status] || 'FA'
  end

  # Check if there's an existing pending payment for given invoices
  def pgpay_exists?(invoice_ids)
    timeout_threshold = get_pg_timeout.minutes.ago
    
    WkPgPaymentItem.joins(:wk_pg_payment)
      .where(invoice_id: invoice_ids)
      .where("(wk_pg_payments.status = ? AND wk_pg_payment_items.created_at >= ?) OR wk_pg_payments.status = ?",
             WkPgPayment::STATUS_INITIATED, timeout_threshold, WkPgPayment::STATUS_SUCCESS)
      .exists?
  end

  # Update timed out payments
  def update_pgpay_timeout(invoice_ids)
    timeout_threshold = get_pg_timeout.minutes.ago
    
    pg_payments = WkPgPayment.joins(:wk_pg_payment_items)
      .where(status: WkPgPayment::STATUS_INITIATED)
      .where(wk_pg_payment_items: { invoice_id: invoice_ids })
      .where('wk_pg_payment_items.created_at <= ?', timeout_threshold)
      .distinct

    pg_payments.find_each do |pg_pay|
      pg_pay.mark_timeout!
    end
  end
end
