module Type
  extend self

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
      return return_type if param_types.empty?

      parameters.join(', ') + ' -> ' + return_type
    end
  end
end

INT = Type::Int.new
BOOL = Type::Bool.new
STRING = Type::String.new
