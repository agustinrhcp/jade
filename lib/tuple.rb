Tuple = Data.define(:first, :second) do
  def map_first
    with(first: yield(first))
  end

  def map_second
    with(second: yield(second))
  end

  def to_ary
    [first, second]
  end
end
