module SendPatch::TimeEntryPatch
  def self.included(base)
    base.class_eval do

      has_one :spent_for, as: :spent, class_name: 'WkSpentFor', :dependent => :destroy
      has_one :invoice_item, through: :spent_for
      has_one :wkstatus, as: :status_for, class_name: "WkStatus", dependent: :destroy
      has_many :attachments, -> {where(container_type: "TimeEntry")}, class_name: "Attachment", foreign_key: "container_id", dependent: :destroy
      accepts_nested_attributes_for :spent_for, :attachments

      def attachments_editable?(user=User.current)
        true
      end

      def attachments_deletable?(user=User.current)
        true
      end

    end
  end
end