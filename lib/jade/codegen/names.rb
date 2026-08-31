module Jade
  module Codegen
    # Ruby rejects its keywords as local variables and parameters, but accepts
    # them as method names and Data members — so only bindings are rewritten
    # here, and nothing a Ruby caller sees changes.
    module Names
      extend self

      RESERVED = ::Set[
        'BEGIN', 'END', '__ENCODING__', '__FILE__', '__LINE__',
        'alias', 'and', 'begin', 'break', 'case', 'class', 'def',
        'defined?', 'do', 'else', 'elsif', 'end', 'ensure', 'false',
        'for', 'if', 'in', 'module', 'next', 'nil', 'not', 'or', 'redo',
        'rescue', 'retry', 'return', 'self', 'super', 'then', 'true',
        'undef', 'unless', 'until', 'when', 'while', 'yield',
      ].freeze

      # Injective: a name that is a reserved word under trailing underscores
      # gains one more, so `begin` and `begin_` stay distinct.
      def local(name)
        reserved_stem?(name) ? "#{name}_" : name
      end

      private

      def reserved_stem?(name)
        RESERVED.include?(name.sub(/_+\z/, ''))
      end
    end
  end
end
