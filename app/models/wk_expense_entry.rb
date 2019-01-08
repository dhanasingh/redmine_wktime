# ERPmine - ERP for service industry
# Copyright (C) 2011-2016  Adhi software pvt ltd
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

class WkExpenseEntry < TimeEntry
  unloadable
  
  self.table_name = "wk_expense_entries" 
  
  belongs_to :project
  belongs_to :issue
  belongs_to :user
  belongs_to :activity, :class_name => 'TimeEntryActivity'
   
   
  # attr_protected :user_id, :tyear, :tmonth, :tweek
  
  scope :visible, lambda {|*args|
    joins(:project).
    where(WkExpenseEntry.visible_condition(args.shift || User.current, *args))
  }
  scope :left_join_issue, lambda {
    joins("LEFT OUTER JOIN #{Issue.table_name} ON #{Issue.table_name}.id = #{WkExpenseEntry.table_name}.issue_id")
  }
  scope :on_issue, lambda {|issue|
    joins(:issue).
    where("#{Issue.table_name}.root_id = #{issue.root_id} AND #{Issue.table_name}.lft >= #{issue.lft} AND #{Issue.table_name}.rgt <= #{issue.rgt}")
  }

  
  validates_numericality_of :amount, :message => :invalid   
  
  #execute query for date range in WkExpenseEntry
  scope :spent_between, lambda {|from, to|
    if from && to
     {:conditions => ["#{WkExpenseEntry.table_name}.spent_on BETWEEN ? AND ?", from, to]}
    elsif from
     {:conditions => ["#{WkExpenseEntry.table_name}.spent_on >= ?", from]}
    elsif to
     {:conditions => ["#{WkExpenseEntry.table_name}.spent_on <= ?", to]}
    else
     {}
    end
  }
  
  #hours function of TimeEntry(base class) is overrided to use amount column of WkExpenseEntry
  
  def validate_time_entry
    errors.add :amount, :invalid if amount && (amount < 0 || amount >= 1000000)
    errors.add :project_id, :invalid if project.nil?
    errors.add :issue_id, :invalid if (issue_id && !issue) || (issue && project!=issue.project)
  end
  
  def spent_for
	WkSpentFor.where(:spent_type => 'WkExpenseEntry', :spent_id => self.id).first_or_initialize
  end  
  
  def hours=(h)
    write_attribute :amount, (h.is_a?(String) ? (h.to_i || h) : h)
  end

  def hours
    h = read_attribute(:amount)
    if h.is_a?(Float)
      h.round(2)
    else
      h
    end
  end 
  
  #set atom event link path
   def event_url(options = {})   
	  option =  Proc.new {|o| {:controller => 'wkexpense', :action => 'reportdetail', :project_id => o.project, :issue_id => o.issue}} 	 
	  if option.is_a?(Proc)
		option.call(self)
	  end
	end
	
	#set atom event title
	def event_title()		
		option = Proc.new {|o| "#{"%.2f" % o.hours} (#{(o.issue || o.project).event_title})"}		 
		if option.is_a?(Proc)
			option.call(self)
		end
	end
end
