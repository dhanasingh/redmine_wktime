class WkCustomField < ActiveRecord::Base
  unloadable
  belongs_to :custom_field, :foreign_key => "custom_fields_id", :primary_key => "id"
  validates :custom_fields_id, presence: true
  validates :display_as, presence: true
  has_one :project, :foreign_key => "id", :primary_key => "projects_id"
  has_one :enumeration, :foreign_key => "id", :primary_key => "enumerations_id"

  def isDocument?
    @custom_field.type.eql? "DocumentCustomField"
  end

  def displayCreation?
    @render_creation
  end
end
