module Jade
  module Frontend
    module ForwardDeclaration
      module Error
        class DuplicateTypeName < Jade::Error
          KINDS = {
            Symbol::Interface => 'an interface',
            Symbol::Union => 'a type',
            Symbol::Struct => 'a struct',
          }.freeze

          def self.kind_of(symbol)
            KINDS.fetch(symbol.class)
          end

          def initialize(entry, span, name, declaring:, existing:, first_span: nil)
            @name = name
            @declaring = declaring
            @existing = existing
            @first_span = first_span
            super(entry:, span:)
          end

          def message
            "`#{@name}` is already declared as #{@existing} in this module"
          end

          def label
            "cannot declare #{@declaring} `#{@name}`"
          end

          def secondary
            return [] unless @first_span

            [[@first_span, 'first declared here']]
          end
        end
      end
    end
  end
end
