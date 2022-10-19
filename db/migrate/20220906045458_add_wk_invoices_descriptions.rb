class AddWkInvoicesDescriptions < ActiveRecord::Migration[6.1]
  def change
    add_column :wk_invoices, :description, :text
    reversible do |dir|
      dir.up do
        change_column :wk_addresses, :pin, :string, limit: 16

        WkOpportunity.all.each do |opp|
          WkStatus.create(status_for_type: 'WkOpportunity', status_for_id: opp.id, status: opp.sales_stage_id, status_date: opp.updated_at, status_by_id: opp.updated_by_user_id)
        end
        remove_column :wk_opportunities, :sales_stage_id, :integer
      end

      dir.down do
        add_reference :wk_opportunities, :sales_stage, class: "wk_crm_enumerations"
        status = WkStatus.joins("INNER JOIN (
          SELECT MAX(status_date) AS status_date, status_for_id
          FROM wk_statuses
          WHERE status_for_type = 'WkOpportunity'
          GROUP BY status_for_id
          ) AS S on wk_statuses.status_for_id = S.status_for_id AND wk_statuses.status_date = S.status_date")
          .where(status_for_type: 'WkOpportunity')
        status.each do |entry|
          opp = WkOpportunity.where(id: entry.status_for_id).first
          opp.update(sales_stage_id: entry.status) if opp.present?
        end
        WkStatus.where(status_for_type: 'WkOpportunity').delete_all
      end
    end
  end
end
