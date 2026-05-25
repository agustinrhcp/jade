require 'jade/codegen/helpers'
require 'jade/codegen/pretty'
require 'jade/codegen/method_names'
require 'jade/codegen/inlines'
require 'jade/codegen/inline'
require 'jade/codegen/boundary'

require 'jade/codegen/emitter'

require 'jade/codegen/constructor_reference'
require 'jade/codegen/variant_declaration'
require 'jade/codegen/pattern/constructor'
require 'jade/codegen/function_declaration'
require 'jade/codegen/function_call'
require 'jade/codegen/implementation'
require 'jade/codegen/port_decoder'

module Jade
  module Codegen
    extend self
    extend Emitter
    extend Helpers

    # Maps [interface_qname, type_var_id] => ruby parameter name. Set by
    # FunctionDeclaration around its body so nested calls can resolve the
    # caller's dict for var-typed constraints. Empty outside any function.
    def dict_env
      @dict_env ||= {}
    end

    def with_dict_env(env)
      prev_env = @dict_env
      @dict_env = env
      yield
    ensure
      @dict_env = prev_env
    end

    # False outside a Module so bare expressions (REPL) get the runtime
    # fallback — no constants exist to reference.
    def hoist_records?
      @hoist_records
    end

    def with_hoisted_records
      prev = @hoist_records
      @hoist_records = true
      yield
    ensure
      @hoist_records = prev
    end

    def record_shape_constant(keys)
      "Record_#{keys.join('_')}"
    end

    def collect_record_shapes(node, shapes = Set.new)
      shapes << node.fields.map(&:key).sort if node.is_a?(AST::RecordLiteral)

      if node.is_a?(AST::Node)
        node.members.each do |m|
          [*node.public_send(m)].each { collect_record_shapes(it, shapes) if it.is_a?(AST::Node) }
        end
      end

      shapes
    end

    def generate_entry(entry, registry)
      generate(entry.ast, registry)
        .then { entry.entry ? "#{load_path}\n#{it}" : it }
        .then { entry.with(generated: it) }
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

        outer, inner, wrappers = with_hoisted_records {
          partition_module_body(body.expressions, registry, name.count('.'))
        }

        inner_module = ["extend self", *inner]
          .join(Pretty.newline(2))
          .then { Pretty.block("module Internal", it) }

        [
          "extend self",
          *shape_consts,
          *outer,
          inner_module,
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

      in AST::VariableReference(symbol: ref, name:)
        case ref.is_a?(Symbol::ValueRef) ? registry.lookup(ref) : ref
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

      in AST::StructDeclaration(name:, record_type:)
        record_type
          .fields
          .keys
          .then { data_define(it) }
          .then { "#{name} = #{it}"}

      in AST::InterfaceDeclaration
        ""

      in AST::QualifiedAccess(symbol:)
        case registry.lookup(symbol)
        in Symbol::StdlibFunction(codegen:)
          codegen

        in Symbol::Function => fn
          "#{to_qualified(fn.module_name)}::Internal.method(:#{fn.name})"

        in Symbol::Constructor => sym
          ConstructorReference.from_symbol(sym)
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
        fields.sort_by(&:key).then { |sorted|
          keys   = sorted.map(&:key)
          values = generate_many(sorted.map(&:value), registry)

          hoist_records? \
            ? "#{record_shape_constant(keys)}[#{values}]"
            : "Jade::Runtime.record(#{keys.map { ":#{it}" }.join(', ')})[#{values}]"
        }

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

    # Splits the module body into three flat lists of pretty-printed chunks:
    # outer (imports, types, interface decls, impl registrations) goes before
    # `module Internal`; inner (function defs, impl fn defs) lives inside it;
    # wrappers (Phase 3 boundary `def self.X(args)`) come after the
    # singleton-method fallthrough loop so they override the proxies.
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

        if MethodNames.operator_interface?(node.symbol.interface.qualified_name)
          methods = Implementation.generate_operator_impl(node, registry)
          [[registrations, methods].reject(&:empty?).join(Pretty.newline(2)), defs, nil]
        else
          [registrations, defs, nil]
        end

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
