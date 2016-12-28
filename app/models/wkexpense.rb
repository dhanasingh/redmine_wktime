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

class Wkexpense < Wktime
  unloadable
  
  self.table_name = "wkexpenses"
  
  validates_numericality_of :amount, :allow_nil => true, :message => :invalid
  
  #hours function of Wktime(base class) is overrided to use amount column of Wkexpense
  
  def validate_wktime
    errors.add :amount, :invalid if amount && (amount < 0)
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
end
