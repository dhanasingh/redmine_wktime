class WkStatus < ActiveRecord::Base
    belongs_to :status_for, :polymorphic => true

    validates_presence_of :status_date, :status
end