module Wkdashboard
  module Graph005AssetsPerMonth
    include WktimeHelper
    include WkcrmHelper

    def chart_data(param={})
      to = param[:to]
      data = { graphName: l(:label_total_assets_per_month), chart_type: "bar", xTitle: l(:label_months), yTitle: l(:field_amount),
        legentTitle1: l(:label_total_assets_per_month), data1: []
      }
      data[:fields] = (Array.new(12){|indx| month_name(((to.month - 1 - indx) % 12) + 1).first(3)}).reverse

      dateArr = (Array.new(12){|m| [(to - m.month).beginning_of_month, (to - m.month).end_of_month]}).reverse
      dateArr.each do |c|
        countEntry = getAssets(c.last.to_date)
        countEntry = countEntry.where("(ap.is_disposed != #{booleanFormat(true)} OR ap.is_disposed is NUll)")
          .select("sum(
            CASE WHEN dp.id IS NULL
            THEN CASE WHEN ap.current_value IS NULL THEN (wk_inventory_items.cost_price + wk_inventory_items.over_head_price) ELSE ap.current_value END
            ELSE (dp.actual_amount-dp.depreciation_amount) END
            ) AS actual_value")
          .order("actual_value")

        data[:data1] << countEntry&.first&.actual_value&.to_f&.round(2)
      end
      return data
    end

    def get_detail_report(param={})
      to = param[:to]
      entries = getAssets(param[:to])
        .group("wk_inventory_items.id, ap.created_at")
        .where("ap.is_disposed IS NULL OR ap.is_disposed = ? OR (ap.is_disposed = ? AND dp.depreciation_date BETWEEN ? AND ?)", false, true, getFromDateTime(to - 12.months + 1.days), getToDateTime(to))
        .order("ap.created_at DESC")
      data = entries.map{|e| {name: e&.asset_property&.name, date: e&.asset_property&.created_at&.to_date, type: e&.asset_property&.is_disposed ? l(:label_deleted) : l(:label_added)}}
      header = {name: l(:field_name), date: l(:label_date), add_delete: l(:label_added)+"/"+l(:label_deleted)}
      return {header: header, data: data}
    end

    private

    def getAssets(to)
      WkInventoryItem.joins("INNER JOIN wk_product_items pt ON (pt.id = wk_inventory_items.product_item_id AND wk_inventory_items.product_type = 'A'"+get_comp_cond('pt')+")")
      .joins("LEFT OUTER JOIN (
          SELECT MAX(depreciation_date) as depreciation_date, inventory_item_id
          FROM wk_asset_depreciations d
          WHERE d.depreciation_date <= '#{to}'"+get_comp_cond('d')+" group by inventory_item_id
        ) md on (md.inventory_item_id = wk_inventory_items.id)")
        .joins("
        LEFT OUTER JOIN wk_asset_depreciations dp on (md.inventory_item_id = dp.inventory_item_id and  md.depreciation_date = dp.depreciation_date "+get_comp_cond('dp')+")
        LEFT OUTER JOIN wk_shipments s ON s.id = wk_inventory_items.shipment_id "+get_comp_cond('s')+"
        LEFT OUTER JOIN wk_asset_properties ap ON (ap.inventory_item_id = wk_inventory_items.id)
        "+get_comp_cond('ap')+"
        LEFT OUTER JOIN projects ON (projects.id = wk_inventory_items.project_id "+get_comp_cond('projects')+")")
        .where("ap.id is not null and s.shipment_date <= '#{to}'")
    end
  end
end