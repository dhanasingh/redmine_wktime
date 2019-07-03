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

class WkGlTransaction < ActiveRecord::Base
  unloadable
  has_many :transaction_details, foreign_key: "gl_transaction_id", class_name: "WkGlTransactionDetail", :dependent => :destroy
  has_one :invoice, foreign_key: "gl_transaction_id", class_name: "WkInvoice"
  has_many :gl_salaries, foreign_key: "gl_transaction_id", class_name: "WkGlSalary", :dependent => :destroy
  has_many :depreciations, foreign_key: "gl_transaction_id", class_name: "WkAssetDepreciation", :dependent => :nullify
  validates_presence_of :trans_date
  
  def trans_date=(date)
    super
    self.tyear = trans_date ? trans_date.cwyear : nil
    self.tmonth = trans_date ? trans_date.month : nil
    self.tweek = trans_date ? Date.civil(trans_date.year, trans_date.month, trans_date.day).cweek : nil
  end
end
