module TokenHelpers
  def tok(type, value, position = Position.new)
    Token.new(type, value, position)
  end
end
