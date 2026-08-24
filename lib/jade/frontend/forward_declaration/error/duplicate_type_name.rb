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

          def initialize(entry, span, name, declaring:, existing:)
            @name = name
            @declaring = declaring
            @existing = existing
            super(entry:, span:)
          end

          def message
            "`#{@name}` is already declared as #{@existing} in this module"
          end

          def label
            "cannot declare #{@declaring} `#{@name}`"
          end
        end
      end
    end
  end
end
