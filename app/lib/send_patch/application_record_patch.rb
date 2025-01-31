module SendPatch::ApplicationRecordPatch
  def self.included(base)
    base.class_eval do

      def self.get_comp_con(table, cond = 'AND')
        company_id = MtRequestCache.get_req_cache || User.current.mt_company_id || nil
        cond = Redmine::Hook.call_hook(:get_comp_condition, comp_id: company_id, table: table, cond: cond) || []
        cond[0] || ""
      end

    end
  end
end