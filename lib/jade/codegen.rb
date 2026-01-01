module Jade
  module Codegen
    extend self

    def generate_entry(entry, registry)
      generate(entry.ast, registry)
        .then { entry.entry ? "#{load_path} #{it}" : it }
        .then { entry.with(generated: it) }
    end

    def generate(node, registry)
      case node
      in AST::Module(name:, body:)
        "require 'jade/runtime'; module #{name}; extend self; #{generate(body, registry)}; end"
      in AST::ImportDeclaration(module_name:)
        registry.get(module_name).path
          .then { "require '#{it}'" }

      in AST::Body(expressions:)
        expressions
          .map { generate(it, registry) }.join("; ")

      in AST::VariableReference(name:)
        name

      in AST::VariableBinding(name:, expression:)
        "#{name} = #{generate(expression, registry)}"

      in AST::Literal(value:)
        case value
        in Integer | TrueClass | FalseClass
          value.to_s

        in String
          "\"#{value}\""
        end

      in AST::FunctionDeclaration(name:, params:, body:)
        params_code = params.map { generate(it, registry) }.join(', ')
        "def #{name}; ->(#{params_code}) { #{generate(body, registry)} }; end"

      in AST::FunctionDeclarationParam(name:)
        name

      in AST::InfixApplication(left:, operator:, right:)
        symbol = registry.lookup(operator.symbol)

        "#{symbol.codegen}.call(#{generate(left, registry)}, #{generate(right, registry)})"

      in AST::FunctionCall(callee:, args:)
        args_code = args.map { generate(it, registry) }.join(', ')

        "#{generate(callee, registry)}.call(#{args_code})"

      in AST::ConstructorReference(name:)
        "->(*args) { #{name}[*args] }"

      in AST::TypeDeclaration(variants:)
        variants.map { generate(it, registry) }.join('; ')

      in AST::VariantDeclaration(name:, args:)
        args.map.with_index { |_, i| ":_#{i + 1}" }
          .then { it.empty? ? "" : "(#{it.join(", ")})"}
          .then { "#{name} = Data.define#{it}" }

      in AST::MemberAccess(symbol:)
        case registry.lookup(symbol)
        in Symbol::StdlibFunction(codegen:)
          codegen
        # TODO: NonStdlibImports

        end

      in AST::IfThenElse(condition:, if_branch:, else_branch:)
        "if (#{generate(condition, registry)}) then; #{generate(if_branch, registry)}; else; #{generate(else_branch, registry)}; end"

      in AST::CaseOf(expression:, branches:)
        "case #{generate(expression, registry)}; " + branches.map { generate(it, registry) }.join + "end"

      in AST::CaseOfBranch(pattern:, body:)
        "in #{generate(pattern, registry)}; #{generate(body, registry)}; "

      in AST::Pattern::Literal(literal:)
        generate(literal, registry)

      in AST::Pattern::Wildcard
        "_"

      in AST::Pattern::Binding(name:)
        name
      end
    end

    private

    def load_path
      return '$LOAD_PATH.unshift(File.expand_path("lib"));'
    end
  end
end
