module SendPatch::ApplicationRecordPatch
  def self.included(base)
    base.class_eval do

      def get_comp_con(table, cond = 'AND')
        cond = Redmine::Hook.call_hook(:get_comp_condition, table: table, cond: cond) || []
        cond[0] || ""
      end

      def self.get_comp_con(table, cond = 'AND')
        cond = Redmine::Hook.call_hook(:get_comp_condition, table: table, cond: cond) || []
        cond[0] || ""
      end

    end
  end
end