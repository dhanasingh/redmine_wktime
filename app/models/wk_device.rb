class WkDevice < ActiveRecord::Base
  belongs_to :user

  validates :user_id, :device_id, presence: true
  validates :device_id, length: { maximum: 100 }
  validates :device_id, uniqueness: { scope: :user_id }

  enum :status, { pending: 0, approved: 1, rejected: 2 }

  def self.check_device(user_id, device_id, device_info = {})
    device = find_or_initialize_by(user_id: user_id, device_id: device_id)
    device.assign_attributes(device_info) if device_info.present?
    device.last_login_at = Time.current
    device.save!
    device
  end
end
