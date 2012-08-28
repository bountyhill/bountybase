module Enumerable
  # transforms the Enumerable into a Hash, which maps the result of
  # the passed in block to each of the objects. It is similar to 
  # Enumerable#group_by, but assumes that the block returns different
  # values for each passed in value in the Enumerable; consequently
  # this method does not return a Hash of Arrays, but a Hash of
  # Objects instead.
  #
  #   a = [ 1, 2, 3]
  #   h = a.by { |int| int*int }
  #   # => { 1 => 1, 2 => 4, 3 => 9} 
  #
  def by(&proc)
    r = {}
    each do |row|
      r[yield(row)] = row
    end
    r
  end
end
