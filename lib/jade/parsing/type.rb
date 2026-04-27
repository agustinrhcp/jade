module Jade
  module Parsing
    module Type
      def type_expression
        type_function | type_atom | type_record
      end

      def type_atom
        type_application | type_var | type_tuple | grouped(lazy { type_function })
      end

      def type_tuple
        (
          type(:lparen) >>
            lazy { type_atom } >>
            type(:comma).skip >>
            sequence(lazy { type_atom }, separated_by: type(:comma).skip).map { [it] } >>
            type(:rparen)
        ).map(&AST.type_tuple)
      end

      def type_record
        (type(:lbrace) >> type_record_row >> type_record_fields >> type(:rbrace)).map(&AST.type_record)
      end

      def type_record_row
        (type_param >> type(:pipe).skip) | none.map { nil }
      end

      def type_record_fields
        sequence(
          (identifier >>
            type(:colon).skip >>
            lazy { type_expression }
          ).map { [it] },
          separated_by: type(:comma).skip,
        ).map { [it] }
      end

      def type_param
        identifier.map(&AST.type_param)
      end

      def type_name
        qualified_type_name | constant.map(&AST.type_name)
      end

      def qualified_type_name
        (constant >> type(:dot).skip >> 
          sequence(constant, separated_by: type(:dot).skip)
        ).map(&AST.qualified_type_name)
      end

      def type_var
        identifier.map(&AST.type_var)
      end

      def type_function
        (
          (unit | sequence(type_atom, separated_by: type(:comma).skip).map { [it] }) >>
          type(:arrow).skip >>
          type_atom
        ).map(&AST.type_function)
      end

      def unit
        (type(:lparen) >> type(:rparen)).map { |lparen, rparen|
          [[AST::TypeUnit[lparen.range.begin..rparen.range.end]]]
        }
      end

      def type_application
        (
          (type_name >> (type_application_args| none.map { [[], nil] })) |
          (type_var  >> type_application_args)
        ).map(&AST.type_application)
      end

      def type_params
        type(:lparen).skip >>
          sequence(type_param, separated_by: type(:comma).skip).map { [it] } >>
          type(:rparen).skip
      end

      def type_expressions
        type(:lparen).skip >>
          sequence(type_expression, separated_by: type(:comma).skip).map { [it] } >>
          type(:rparen).skip
      end

      private

      def type_application_args
        type(:lparen).skip >>
          sequence(lazy { type_expression }, separated_by: type(:comma).skip).map { [it] } >>
          type(:rparen)
      end
    end
  end
end
