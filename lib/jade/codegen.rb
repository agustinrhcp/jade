require 'jade/codegen/context'
require 'jade/codegen/helpers'
require 'jade/codegen/pretty'
require 'jade/codegen/method_names'
require 'jade/codegen/inlines'
require 'jade/codegen/inline'
require 'jade/codegen/boundary'
require 'jade/codegen/boundary/cache'
require 'jade/codegen/boundary/specialized'

require 'jade/codegen/emitter'

require 'jade/codegen/constructor_reference'
require 'jade/codegen/variant_declaration'
require 'jade/codegen/pattern/constructor'
require 'jade/codegen/transforms/self_call'
require 'jade/codegen/transforms/tail_call'
require 'jade/codegen/transforms/fold_shape'
require 'jade/codegen/function_declaration'
require 'jade/codegen/function_call'
require 'jade/codegen/implementation'
require 'jade/codegen/port_decoder'

module Jade
  module Codegen
    extend self
    extend Emitter
    extend Helpers
    extend Context

    def record_shape_constant(keys)
      "Record_#{keys.join('_')}"
    end

    def collect_record_shapes(node, shapes = ::Set.new)
      shapes << node.fields.map(&:key).sort if node.is_a?(AST::RecordLiteral)

      if node.is_a?(AST::Node)
        node.members.each do |m|
          [*node.public_send(m)].each { collect_record_shapes(it, shapes) if it.is_a?(AST::Node) }
        end
      end

      shapes
    end

    def collect_dispatched_methods(body, registry)
      body.expressions
        .filter { it.is_a?(AST::Implementation) }
        .filter { MethodNames.operator_interface?(it.symbol.interface.qualified_name) }
        .flat_map do |node|
          methods = Implementation.method_bodies_for(node, registry)
          ruby_classes_for_type(node.symbol.type, registry).map { [it, methods] }
        end
        .group_by(&:first)
        .transform_values { |pairs| pairs.flat_map(&:last) }
    end

    def data_define_with_methods(name, fields, ruby_class)
      methods = dispatched_methods[ruby_class] || []
      base    = data_define(fields)

      if methods.empty?
        "#{name} = #{base}"
      else
        methods
          .join(Pretty.newline(2))
          .then { Pretty.block("#{name} = #{base} do", it) }
      end
    end

    def generate_entry(entry, registry)
      generate(entry.ast, registry)
        .then { entry.entry ? "#{load_path}\n#{it}" : it }
        .then { entry.with(generated: it) }
    end

    def reference_emission(resolved, dictionaries, registry, &fallback)
      FunctionCall.reference_with_dictionaries(resolved, dictionaries, registry) || fallback.call
    end

    def generate(node, registry, depth: 0)
      case node
      in AST::Module(name:, body:)
        preamble = [
          "require 'jade/runtime'",
          *Stdlib.requires(name),
          *namespace_setup_lines(name),
        ].reject(&:empty?).join(Pretty.newline)

        shape_consts = collect_record_shapes(body)
          .sort
          .map { |keys|
            "#{record_shape_constant(keys)} = Data.define(#{keys.map { ":#{it}" }.join(', ')})"
          }

        boundary_cache   = Boundary::Cache.collect(body, registry)
        boundary_consts  = Boundary::Cache.constants(boundary_cache, registry)
        boundary_helpers = Boundary::Specialized.collect_helpers(body, registry)
          .then { Boundary::Specialized.emit_helpers(it, registry) }

        outer, inner, wrappers =
          with_boundary_cache(boundary_cache) do
            with_dispatched_methods(collect_dispatched_methods(body, registry)) do
              with_hoisted_records do
                partition_module_body(body.expressions, registry, name.count('.'))
              end
            end
          end

        inner_module = ["extend self", *inner]
          .join(Pretty.newline(2))
          .then { Pretty.block("module Internal", it) }

        [
          "extend self",
          *shape_consts,
          *outer,
          inner_module,
          *boundary_consts,
          *boundary_helpers,
          *wrappers,
        ]
          .reject(&:empty?)
          .join(Pretty.newline(2))
          .then { Pretty.block("module #{to_qualified(name)}", it) }
          .then { [preamble, it].reject(&:empty?).join(Pretty.newline(2)) }

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
        Pretty.block("begin", "require '#{mod.name.gsub('::', '/').downcase}'\nrescue LoadError")

      in AST::Implementation
        Implementation.generate(node, registry)

      in AST::Body(expressions:)
        expressions
          .map { generate(it, registry, depth:) }
          .reject(&:empty?)
          .join("\n")

      in AST::VariableReference(name:) if name == self_var_name
        'self'

      in AST::VariableReference(symbol: ref, name:, dictionaries:)
        resolved = ref.is_a?(Symbol::ValueRef) ? registry.lookup(ref) : ref

        reference_emission(resolved, dictionaries, registry) do
          case resolved
          in Symbol::InteropFunction => sym
            registry
              .lookup(sym.to_ref)
              .then { PortDecoder.task_call(it, registry) }

          in Symbol::StdlibFunction(codegen:)
            codegen

          in Symbol::Function => fn
            "#{to_qualified(fn.module_name)}::Internal.method(:#{fn.name})"

          else
            name
          end
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

      in AST::ConstructorReference
        ConstructorReference.generate(node, registry)

      in AST::TypeDeclaration(variants:)
        variants
          .map { VariantDeclaration.generate(it, variants.map(&:name)) }
          .join(Pretty.newline(2))

      in AST::StructDeclaration(name:, record_type:, symbol:)
        data_define_with_methods(name, record_type.fields.keys, "::#{to_qualified(symbol.qualified_name)}")

      in AST::InterfaceDeclaration
        ""

      in AST::QualifiedAccess(symbol:, dictionaries:)
        resolved = registry.lookup(symbol)

        reference_emission(resolved, dictionaries, registry) do
          case resolved
          in Symbol::StdlibFunction(codegen:)
            codegen

          in Symbol::Function => fn
            "#{to_qualified(fn.module_name)}::Internal.method(:#{fn.name})"

          in Symbol::Constructor => sym
            ConstructorReference.from_symbol(sym)
          end
        end

      in AST::IfThenElse(condition:, if_branch:, else_branch:)
        [
          "if (#{generate(condition, registry)})",
          Pretty.indent(generate(if_branch, registry)),
          "else",
          Pretty.indent(generate(else_branch, registry)),
          "end",
        ].join(Pretty.newline)

      in AST::CaseOf(expression:, branches:)
        branches
          .map { generate(it, registry) }
          .join("\n")
          .then { "case #{generate(expression, registry)}\n#{it}\nend" }

      in AST::CaseOfBranch(pattern:, body:)
        pat  = generate(pattern, registry)
        body = generate(body, registry)

        Pretty.multiline?(body) \
          ? "in #{pat} then\n#{Pretty.indent(body)}"
          : "in #{pat} then #{body}"

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

        Pretty.array(patterns.map { generate(it, registry) } + rest_part)

      in AST::Pattern::Constructor
        Pattern::Constructor.generate(node, registry)

      in AST::Lambda(params:, body:)
        param_strs = params.zip(0..).map { |p, i| param_name(p, i) }

        params
          .zip(0..)
          .filter_map { |p, i| "#{param_synthetic_name(i)} => #{generate(p, registry)}" unless simple_pattern?(p) }
          .then { (it + [generate(body, registry)]).join("\n") }
          .then { Pretty.lambda(param_strs.join(', '), it) }

      in AST::Grouping(expression:)
        "(#{generate(expression, registry)})"

      in AST::List(items:)
        Pretty.array(items.map { generate(it, registry) })

      in AST::RecordLiteral(fields:)
        fields.sort_by(&:key).then do |sorted|
          keys   = sorted.map(&:key)
          values = generate_many(sorted.map(&:value), registry)

          hoist_records? \
            ? "#{record_shape_constant(keys)}[#{values}]"
            : "Jade::Runtime.record(#{keys.map { ":#{it}" }.join(', ')})[#{values}]"
        end

      in AST::RecordField(key:, value:)
        "#{key}: #{generate(value, registry)}"

      in AST::RecordAccess(target:, name:)
        if self_var_name && target.is_a?(AST::VariableReference) && target.name == self_var_name
          name.name
        else
          "#{generate(target, registry)}.#{name.name}"
        end

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

    def relative_require(import_path, current_depth)
      "#{'../' * current_depth}#{import_path}"
    end

    def namespace_setup_lines(name)
      parts = name.split('.')
      (0...parts.length - 1)
        .map { parts[0..it].join('::') }
        .then { |prefixes| Stdlib.stdlib_name?(name) ? ['Jade'] + prefixes.map { "Jade::#{it}" } : prefixes }
        .map { "module #{it}; end" }
    end

    # Returns [outer, inner, wrappers]: outer goes before `module Internal`,
    # inner lives inside it, wrappers come after the singleton-method
    # fallthrough loop so they override the proxies.
    def partition_module_body(expressions, registry, depth)
      expressions
        .chunk_while { |a, b| import?(a) && import?(b) }
        .flat_map { group_chunks(it, registry, depth) }
        .then { it.empty? ? [[], [], []] : it.transpose.map { |b| b.compact.reject(&:empty?) } }
    end

    def group_chunks(group, registry, depth)
      if group.all? { import?(it) }
        group
          .map { generate(it, registry, depth:) }
          .reject(&:empty?)
          .join("\n")
          .then { [[it, nil, nil]] }
      else
        group.map { generate_for_partition(it, registry, depth) }
      end
    end

    def generate_for_partition(node, registry, depth)
      case node
      in AST::Implementation
        registrations = Implementation.generate_registrations_for(node, registry)
        defs          = Implementation.generate_defs(node, registry)

        [registrations, defs, nil]

      in AST::FunctionDeclaration
        [
          nil,
          generate(node, registry, depth:),
          FunctionDeclaration.generate_boundary_wrapper(node, registry),
        ]

      else
        [generate(node, registry, depth:), nil, nil]
      end
    end

    def import?(node)
      node.is_a?(AST::ImportDeclaration) || node.is_a?(AST::InteropImportDeclaration)
    end

    def load_path
      '$LOAD_PATH.unshift(File.expand_path("lib"))'
    end
  end
end
