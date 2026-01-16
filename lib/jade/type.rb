module Jade
  module Type
    extend self

    def var(name)
      Var[name]
    end

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

    def list
      constructor('List.List')
    end

    def constructor(name)
      Constructor[name]
    end

    def function(args, return_type)
      Function[args, return_type]
    end

    def anonymous_record(fields, row_var)
      AnonymousRecord[fields, row_var]
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

      def apply(types)
        return self if types.empty?

        Application[self, types]
      end
    end

    Function = Data.define(:args, :return_type) do
      def to_s
        args
          .map(&:to_s).join(', ')
          .then { "(#{it})"} + " -> " + return_type.to_s
      end

      def free_vars
        (args.flat_map(&:free_vars) + return_type.free_vars)
          .then(&:to_set)
          .then(&:to_a)
      end
    end

    Application = Data.define(:constructor, :args) do
      def to_s
        "#{constructor.to_s}(#{args.join(", ")})"
      end

      def free_vars
        args
          .flat_map(&:free_vars)
          .then(&:to_set)
          .then(&:to_a)
      end
    end

    Unit = Data.define() do
      def inspect
        '()'
      end
      alias_method :to_s, :inspect

      def free_vars
        []
      end
    end

    AnonymousRecord = Data.define(:fields, :row_var) do
      def to_s
        row = row_var ? "#{row_var} | " : ""

        fields
          .map { |name, type| "#{name} : #{type}" }
          .join(", ")
          .then { "{ #{row}#{it} }" }
      end

      def free_vars
        [] + (row_var&.free_vars || [])
      end

      def open?
        !closed?
      end

      def closed?
        row_var.nil?
      end

      def field_names
        fields.keys
      end
    end
  end
end
