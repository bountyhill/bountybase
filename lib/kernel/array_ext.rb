class Array
  def pluck(key)
    map { |row| row[key] }
  end
end

