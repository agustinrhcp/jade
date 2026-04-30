require 'jade/codegen/helpers'

require 'jade/codegen/emitter'

require 'jade/codegen/function_declaration'
require 'jade/codegen/function_call'
require 'jade/codegen/implementation'

module Jade
  module Codegen
    extend self
    extend Emitter
    extend Helpers

    def generate_entry(entry, registry)
      generate(entry.ast, registry)
        .then { entry.entry ? "#{load_path} #{it}" : it }
        .then { entry.with(generated: it) }
    end

    def generate(node, registry, depth: 0)
      case node
      in AST::Module(name:, body:)
        qualified = to_qualified(name)
        body_str  = generate(body, registry, depth: name.count('.'))
        namespace = namespace_setup(name)
        "require 'jade/runtime'; #{Stdlib.requires(name)}#{namespace}module #{qualified}; extend self; #{body_str}; end"

      in AST::ImportDeclaration(module_name:)
        entry = registry.get(module_name)
        if Stdlib.is_stdlib?(entry)
          ""
        else
          entry.path
            .then { relative_require(it, depth) }
            .then { "require_relative '#{it}'" }
        end

      in AST::InteropImportDeclaration(module: mod)
        "begin; require '#{mod.name.gsub('::', '/').downcase}'; rescue LoadError; end"

      in AST::Implementation
        Implementation.generate(node, registry)

      in AST::Body(expressions:)
        expressions
          .map { generate(it, registry, depth:) }
          .join("; ")

      in AST::VariableReference(symbol:, name:)
        symbol = symbol.is_a?(Symbol::ValueRef) ? registry.lookup(symbol) : symbol

        case symbol
        in Symbol::InteropFunction
          lower_to_ruby(symbol.expected_type)
            .then { "#{symbol.interop_module_name}, :#{symbol.name}, #{it}" }
            .then { "Jade::Runtime.guard(#{it})" }

        in Symbol::StdlibFunction(codegen:)
          codegen

        else
          name
        end

      in AST::Assign(pattern:, expression:)
        case pattern
        in AST::Pattern::Binding(name:)
          "#{name} = #{generate(expression, registry)}"
        in AST::Pattern::Wildcard
          generate(expression, registry)
        else
          "#{generate(expression, registry)} => #{generate(pattern, registry)}"
        end

      in AST::Literal(value:)
        emit(value)

      in AST::CharLiteral(value:)
        emit(value)

      in AST::FunctionDeclaration
        FunctionDeclaration.generate(node, registry)

      in AST::FunctionDeclarationParam(name:)
        name

      in AST::FunctionCall
        FunctionCall.generate(node, registry)

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

      in AST::InterfaceDeclaration
        ""


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

        in Symbol::Constructor(module_name:, name:)
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

      in AST::Pattern::List(patterns:, rest:)
        rest_part =
          case rest
          in AST::Pattern::Binding(name:) then ["*#{name}"]
          in AST::Pattern::Wildcard then ["*"]
          in nil then []
          end

        (patterns.map { generate(it, registry) } + rest_part)
          .join(', ')
          .then { "[#{it}]" }

      in AST::Pattern::Constructor(symbol:, patterns:)
        sym = registry.lookup(symbol)

        generate_many(patterns, registry)
          .then { it.empty? ? it : "(#{it})"}
          .then { "#{to_qualified(sym.qualified_name)}#{it}" }

      in AST::Lambda(params:, body:)
        param_strs = params.zip(0..).map { |p, i| param_name(p, i) }

        destructures = params
          .zip(0..)
          .filter_map { |p, i| "#{param_synthetic_name(i)} => #{generate(p, registry)}; " unless simple_pattern?(p) }
          .join

        "->(#{param_strs.join(', ')}) { #{destructures}#{generate(body, registry)} }"

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

    def param_name(pattern, index = 0)
      case pattern
      in AST::Pattern::Binding(name:) then name
      in AST::Pattern::Wildcard then '_'
      else
         param_synthetic_name(index)
      end
    end

    def simple_pattern?(pattern)
      pattern.is_a?(AST::Pattern::Binding) || pattern.is_a?(AST::Pattern::Wildcard)
    end

    def generate_many(nodes, registry, sep = ", ")
      nodes.map do
        next yield(it) if block_given?

        generate(it, registry)
      end.join(sep)
    end

    def relative_require(import_path, current_depth)
      prefix = '../' * current_depth
      "#{prefix}#{import_path}"
    end

    def namespace_setup(name)
      first, *rest = name.split('.')

      rest
        .reduce([[], first]) do |(paths, prev), part|
          [paths + [prev], "#{prev}::#{part}"]
        end
        .first
        .map { "module #{it}; end; " }
        .join
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
