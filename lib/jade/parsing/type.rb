require 'jade/parsing/combinators'

module Jade
  module Parsing
    module Type
      extend Combinators::Dsl

      parser(:type_expression) { type_function | type_atom | type_record }

      parser(:type_atom) {
        type_application | type_var | type_tuple | grouped(lazy { type_function })
      }

      parser(:type_tuple) {
        (
          type(:lparen) >>
            lazy { type_atom } >>
            type(:comma).skip >>
            comma_sequence(lazy { type_atom }) >>
            type(:rparen)
        ).map(&AST.type_tuple)
      }

      parser(:type_record) {
        (type(:lbrace) >> type_record_row >> type_record_fields >> type(:rbrace)).map(&AST.type_record)
      }

      parser(:type_record_row) { optional(type_param >> type(:pipe).skip) }

      parser(:type_record_fields) {
        comma_sequence(
          (identifier >>
            type(:colon).skip >>
            lazy { type_expression }
          ).map { [it] },
        )
      }

      parser(:type_param) { identifier.map(&AST.type_param) }

      parser(:type_name) { qualified_type_name | constant.map(&AST.type_name) }

      parser(:qualified_type_name) {
        (constant >> type(:dot).skip >>
          sequence(constant, separated_by: type(:dot).skip)
        ).map(&AST.qualified_type_name)
      }

      parser(:type_var) { identifier.map(&AST.type_var) }

      parser(:type_function) {
        atoms = sequence(type_atom, separated_by: type(:comma).skip)
        params = unit | (atoms >> maybe(type(:comma))).map { [it] }

        (params >> type(:arrow).skip >> type_atom).map(&AST.type_function)
      }

      parser(:unit) {
        (type(:lparen) >> type(:rparen)).map { |lparen, rparen|
          [[AST::TypeUnit[lparen.range.begin..rparen.range.end]]]
        }
      }

      parser(:type_application) {
        no_args = [Combinators::CommaList.empty, nil]

        (
          (type_name >> optional(type_application_args, default: no_args)) |
          (type_var  >> type_application_args)
        ).map(&AST.type_application)
      }

      parser(:type_params) {
        type(:lparen).skip >>
          comma_sequence(type_param) >>
          type(:rparen).skip
      }

      parser(:type_expressions) {
        type(:lparen).skip >>
          comma_sequence(type_expression) >>
          type(:rparen).skip
      }

      parser(:type_application_args, private: true) {
        type(:lparen).skip >>
          comma_sequence(lazy { type_expression }) >>
          type(:rparen)
      }
    end
  end
end
