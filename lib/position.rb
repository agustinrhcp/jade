Position = Data.define(:line, :column) do
  def initialize(line: 1, column: 1)
    super
  end

  def offset_by_string(str)
    lines = str.split("\n")
  
    if lines.size == 1
      with(column: column + lines[0].size)
    else
      with(line: line + lines.size - 1, column: lines.last.size + 1)
    end
  end
end
