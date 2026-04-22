require 'jade/type'
require 'jade/parsing'
require 'jade/lexer'

module Jade
  module TypeFactory
    module Parser
      include Jade::Parsing::Combinators
      extend self

      def parse(tokens)
        parser
          .call(State.new(tokens))
          .map(&:first) => Ok(type)

        type
      end

      private

      def parser
        type_expression
      end

      def type_expression
        function | atom | record
      end

      def record
        (
          type(:lbrace).skip >>
            record_row >>
            record_fields >>
            type(:rbrace).skip
        )
          .map do |(row, fields)|
            Type.anonymous_record(
              fields.to_h.transform_keys(&:value),
              row,
            )
          end
      end

      def record_row
        (var >> type(:pipe).skip) | none.map { nil }
      end

      def record_fields
        sequence(
          (type(:identifier) >>
            type(:colon).skip >>
            lazy { type_expression }
          ).map { [it] },
          separated_by: type(:comma).skip,
        ).map { [it] }
      end

      def var
        type(:identifier)
          .map { Type.var(it.value) }
      end

      def atom
        var | application | grouped(lazy { function })
      end

      def function
        (sequence(atom, separated_by: type(:comma).skip).map { [it] } >>
          type(:arrow).skip >>
          atom
        ).map { |(params, ret_type)| Type.function(params, ret_type) }
      end

      def constructor_name
        (
          (
            type(:constant) >> type(:dot).skip >> 
            sequence(type(:constant), separated_by: type(:dot).skip)
          )
            .map { it.map(&:value).join('.') }
        ) | type(:constant).map(&:value)
      end

      def application
        (
          constructor_name >> (
            (
              type(:lparen).skip >>
                sequence(
                  lazy { type_expression },
                  separated_by: type(:comma).skip
                ).map { [it] } >>
                type(:rparen).skip
            ) | none.map { [[]] }
          )
        ).map do |(constructor, args)|
          qualified_constructor =
            case constructor
            in 'Int' then 'Basics.Int'
            in 'String' then 'String.String'
            in 'Maybe' then 'Maybe.Maybe'
            in 'Never' then 'Basics.Never'
            else
              constructor
            end

          Type.constructor(qualified_constructor).apply(args)
        end
      end
    end
  end
end
