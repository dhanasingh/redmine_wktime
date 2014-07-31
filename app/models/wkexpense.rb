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
