require 'position'

Token = Data.define(:type, :value, :position) do
  def initialize(type:, value:, position: Position.new)
    super
  end

  def line
    position.line
  end

  def column
    position.column
  end
end
