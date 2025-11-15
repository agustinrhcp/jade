module Jade
  module Type
    extend self

    def unit
      Unit[]
    end

    def int
      constructor('Basics.Int')
    end

    def unit
      constructor('Basics.Unit')
    end

    def float
      constructor('Basics.Float')
    end

    def string
      constructor('String.String')
    end

    def bool
      constructor('Basics.Bool')
    end

    def constructor(name)
      Constructor[name]
    end

    def function(args, return_type)
      Function[args, return_type]
    end

    Var = Data.define(:name) do
      def to_s
        name
      end

      def free_vars
        [name]
      end
    end

    Constructor = Data.define(:name) do
      def to_s
        name.split('.').last
      end

      def free_vars
        []
      end
    end

    Function = Data.define(:args, :return_type) do
      def to_s
        args
          .map(&:to_s).join(', ')
          .then { "(#{it})"} + " -> " + return_type.to_s
      end

      def free_vars
        (args.values.flat_map(&:free_vars) + return_type.free_vars)
          .then(&:to_set)
          .then(&:to_a)
      end
    end

    Unit = Data.define() do
      def to_s
        '()'
      end

      def free_vars
        []
      end
    end
  end
end
