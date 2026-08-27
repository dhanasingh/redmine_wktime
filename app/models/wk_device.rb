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

class WkDevice < ActiveRecord::Base
  belongs_to :user

  # Transient (not persisted): set by check_device when a device is denied because
  # the employee is single-device only, so the controller can tell the mobile app why.
  attr_accessor :single_device_denied

  validates :user_id, :device_id, presence: true
  validates :device_id, length: { maximum: 100 }
  validates :device_id, uniqueness: { scope: :user_id }

  # `scopes: false` because a `new` status would otherwise generate a
  # `WkDevice.new` class scope, which collides with the constructor.
  enum :status, { new: 0, approved: 1, rejected: 2 }, scopes: false

  def self.check_device(user_id, device_id, device_info = {})
    device = find_or_initialize_by(user_id: user_id, device_id: device_id)
    device.assign_attributes(device_info) if device_info.present?
    device.last_login_at = Time.current

    wk_user = WkUser.find_by(user_id: user_id)

    # Single-device employees (allow_multi_device off) may keep only one active
    # (new/approved) device. Deny any additional unknown device WITHOUT recording
    # it: no row is created, so nothing shows in the admin list. The controller
    # still returns a rejected status + reason so the app can show the message.
    if device.new_record? && !wk_user&.allow_multi_device? &&
       where(user_id: user_id).where.not(status: :rejected).exists?
      device.reject
      device.single_device_denied = true
      return device
    end

    if device.new? && wk_user&.auto_approve_device?
      # Auto-approve a device still in "new" status when the employee is flagged for
      # it, so the mobile app skips the "Awaiting Device Approval" page. Never
      # overrides a manual reject or an existing approval (both fail the `new?` guard).
      device.approve
    end

    device.save!
    device
  end

  # Single source of truth for approving a device. Shared by the auto-approve
  # flow (check_device) and the manual admin "Approve" action so approval logic
  # stays in sync; callers persist via save/save!. Put any future on-approval
  # side effects (notifications, audit, etc.) here.
  def approve
    self.status = :approved
  end

  # Single source of truth for denying a device. Shared by the single-device
  # enforcement in check_device and the manual admin "Reject" action.
  def reject
    self.status = :rejected
  end
end
