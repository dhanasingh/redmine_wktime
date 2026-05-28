class WkGrpLocPermission < ApplicationRecord
  belongs_to :group, class_name: 'Group'
  belongs_to :location, class_name: 'WkLocation'

  validates :group_id,    presence: true
  validates :location_id, presence: true, uniqueness: { scope: :group_id }
end
