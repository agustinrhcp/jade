require 'jade/codegen/helpers'

require 'jade/codegen/function_declaration'

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
        "require 'jade/runtime'; #{Stdlib.requires(name)}module #{name}; extend self; #{generate(body, registry)}; end"

      in AST::ImportDeclaration(module_name:)
        registry.get(module_name).path
          .then { "require_relative '#{it}'" }

      in AST::InteropImportDeclaration
        ""

      in AST::Body(expressions:)
        generate_many(expressions, registry, "; ")

      in AST::VariableReference(symbol:, name:)
        symbol = symbol.is_a?(Symbol::ValueRef) ? registry.lookup(symbol) : symbol

        case symbol
        in Symbol::InteropFunction
          lower_to_ruby(symbol.expected_type)
            .then { "#{symbol.interop_module_name}, :#{symbol.name}, #{it}" }
            .then { "Jade::Runtime.guard(#{it})" }

        in Symbol::StdlibFunction(codegen:)
          codegen

        in Symbol::InterfaceFunction
          impl_fn_sym_ref = registry.implementations[
            [symbol.interface.qualified_name, 'Basics.Int']
          ].functions[symbol.name]

          impl_fn_sym = registry.lookup(impl_fn_sym_ref)
          impl_fn_sym.codegen
        else
          name
        end

      in AST::VariableBinding(name:, expression:)
        "#{name} = #{generate(expression, registry)}"

      in AST::Literal(value:)
        case value
        in Integer | TrueClass | FalseClass | Float
          value.to_s

        in String
          "\"#{value}\""
        end

      in AST::FunctionDeclaration
        FunctionDeclaration.generate(node, registry)

      in AST::FunctionDeclarationParam(name:)
        name

      in AST::InfixApplication(left:, operator:, right:)
        symbol = registry.lookup(operator.symbol)

        operator_as_var_ref = AST::VariableReference.new(
          name: "(#{operator.value})",
          symbol: operator.symbol,
          range: nil,
        )

        "#{generate(operator_as_var_ref, registry)}.call(#{generate(left, registry)}, #{generate(right, registry)})"

      in AST::FunctionCall(callee:, args:)
        args_code = generate_many(args, registry)

        "#{generate(callee, registry)}.call(#{args_code})"

      in AST::ConstructorReference(name:, symbol:)
        to_qualified(symbol.qualified_name) + ".method(:[])"

      in AST::TypeDeclaration(variants:)
        generate_many(variants, registry, '; ')

      in AST::StructDeclaration(name:, record_type:)
        record_type
          .fields
          .keys
          .then { data_define(it) }
          .then { "#{name} = #{it}"}
        

      in AST::VariantDeclaration(name:, args:)
        args
          .map
          .with_index { |_, i| "_#{i + 1}" }
          .then { data_define(it) }
          .then { "#{name} = #{it}" }

      in AST::QualifiedAccess(symbol:)
        case registry.lookup(symbol)
        in Symbol::StdlibFunction(codegen:)
          codegen

        in Symbol::Function(module_name:, name:)
          to_qualified(module_name) + ".#{name}"

        in Symbol::Variant(module_name:, name:)
          to_qualified(module_name + "." + name) + ".method(:[])"
        end

      in AST::IfThenElse(condition:, if_branch:, else_branch:)
        "if (#{generate(condition, registry)}) then; #{generate(if_branch, registry)}; else; #{generate(else_branch, registry)}; end"

      in AST::CaseOf(expression:, branches:)
        "case #{generate(expression, registry)}; " + generate_many(branches, registry, "") + "end"

      in AST::CaseOfBranch(pattern:, body:)
        "in #{generate(pattern, registry)} then #{generate(body, registry)}; "

      in AST::Pattern::Literal(literal:)
        generate(literal, registry)

      in AST::Pattern::Wildcard
        "_"

      in AST::Pattern::Binding(name:)
        name

      in AST::Pattern::Record(fields:)
        generate_many(fields, registry)
          .then { "{ #{it} }"}

      in AST::Pattern::RecordField(name:, pattern:)
          "#{name}: #{generate(pattern, registry)}"

      in AST::Pattern::Constructor(symbol:, patterns:)
        sym = registry.lookup(symbol)

        generate_many(patterns, registry)
          .then { it.empty? ? it : "(#{it})"}
          .then { "#{to_qualified(sym.qualified_name)}#{it}" }

      in AST::Lambda(params:, body:)
        "->(#{params.map(&:name).join(', ')}) { #{generate(body, registry)} }"

      in AST::Grouping(expression:)
        "(#{generate(expression, registry)})"

      in AST::List(items:)
        "[#{generate_many(items, registry)}]"

      in AST::RecordLiteral(fields:)
        fields_sorted = fields.sort_by { it.key }

        data_define(fields.map(&:key).sort) +
          "[#{generate_many(fields_sorted.map(&:value), registry)}]"

      in AST::RecordField(key:, value:)
        "#{key}: #{generate(value, registry)}"

      in AST::RecordAccess(target:, name:)
        "#{generate(target, registry)}.#{name.name}"

      in AST::RecordUpdate(base:, fields:)
        generate_many(fields, registry)
          .then { "#{generate(base, registry)}.with(#{it})" }
      end
    end

    private

    def generate_many(nodes, registry, sep = ", ")
      nodes.map do
        next yield(it) if block_given?

        generate(it, registry)
      end.join(sep)
    end

    def to_qualified(module_name)
      "#{module_name.gsub('.', '::')}"
    end

    def data_define(fields)
      return "Data.define" if fields.empty?

      "Data.define(#{fields.map { ":#{it}" }.join(', ')})"
    end

    def load_path
      return '$LOAD_PATH.unshift(File.expand_path("lib"));'
    end

    def lower_to_ruby(value)
      case value
      in String
        value.dump

      in Array
        value
          .map { |v| lower_to_ruby(v) }.join(", ")
          .then { "[#{it}]" }

      in Hash
        value
          .map { |k, v| "#{lower_to_ruby(k)} => #{lower_to_ruby(v)}" }
          .join(", ")
          .then { "{ #{it}}" }
      end
    end
  end
end
