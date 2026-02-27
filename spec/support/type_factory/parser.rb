require 'jade/type'
require 'jade/parser'
require 'jade/lexer'

module Jade
  module TypeFactory
    module Parser
      extend self

      def parse(tokens)
        parser
          .call(Jade::Parser::State.new(tokens))
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
          Jade::Parser.type(:lbrace).skip >>
            record_row >>
            record_fields >>
            Jade::Parser.type(:rbrace).skip
        )
          .map do |(row, fields)|
            Type.anonymous_record(
              fields.to_h.transform_keys(&:value),
              row,
            )
          end
      end

      def record_row
        (var >> Jade::Parser.type(:pipe).skip) | Jade::Parser.none.map { nil }
      end

      def record_fields
        Jade::Parser.sequence(
          (Jade::Parser.type(:identifier) >>
            Jade::Parser.type(:colon).skip >>
            Jade::Parser.lazy { type_expression }
          ).map { [it] },
          separated_by: Jade::Parser.type(:comma).skip,
        ).map { [it] }
      end

      def var
        Jade::Parser
          .type(:identifier)
          .map { Type.var(it.value) }
      end

      def atom
        var | application | Jade::Parser.grouped(Jade::Parser.lazy { function })
      end

      def function
        (Jade::Parser.sequence(atom, separated_by: Jade::Parser.type(:comma).skip).map { [it] } >>
          Jade::Parser.type(:arrow).skip >>
          atom
        ).map { |(params, ret_type)| Type.function(params, ret_type) }
      end

      def constructor_name
        (
          (
            Jade::Parser.type(:constant) >> Jade::Parser.type(:dot).skip >> 
            Jade::Parser.sequence(Jade::Parser.type(:constant), separated_by: Jade::Parser.type(:dot).skip)
          )
            .map { it.map(&:value).join('.') }
        ) | Jade::Parser.type(:constant).map(&:value)
      end

      def application
        (
          constructor_name >> (
            (
              Jade::Parser.type(:lparen).skip >>
                Jade::Parser.sequence(
                  Jade::Parser.lazy { type_expression },
                  separated_by: Jade::Parser.type(:comma).skip
                ).map { [it] } >>
                Jade::Parser.type(:rparen).skip
            ) | Jade::Parser.none.map { [[]] }
          )
        ).map do |(constructor, args)|
          qualified_constructor =
            case constructor
            in 'Int' then 'Basics.Int'
            in 'String' then 'String.String'
            in 'Maybe' then 'Maybe.Maybe'
            else
              constructor
            end

          Type.constructor(qualified_constructor).apply(args)
        end
      end
    end
  end
end
