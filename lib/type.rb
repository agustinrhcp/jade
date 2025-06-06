module Type
  extend self

  def int
    @int ||= Type::Int.new
  end

  def string
    @string ||= Type::String.new
  end

  def bool
    @bool ||= Type::Bool.new
  end

  Int = Data.define do
    def to_s; 'Int'; end
  end

  Bool = Data.define do
    def to_s; 'Bool'; end
  end

  String = Data.define do
    def to_s; 'String'; end
  end

  Function = Data.define(:parameters, :return_type) do
    def to_s
      return return_type if parameters.empty?

      parameters.map(&:to_s).join(', ') + ' -> ' + return_type.to_s
    end
  end

  Record = Data.define(:name) do
    def to_s
      name
    end
  end
end
