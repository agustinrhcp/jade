require 'jade'
require 'jade/module_loader'
require 'jade/signature'

module Jade
  # The public surface of everything a module can call, read from the registry
  # rather than the source. Stdlib modules are written both as Jade heredocs
  # and as a Ruby DSL, and an extension gem's modules aren't in the tree at
  # all, so no grep of the source finds them.
  Api = Data.define(:registry, :source_root, :skipped) do
    def self.load(project = Project.find)
      project ? of_project(project) : stdlib
    end

    def self.stdlib
      new(registry: stdlib_registry, source_root: nil, skipped: [])
    end

    def self.stdlib_registry
      @stdlib_registry ||= Stdlib.load(Registry.new)
    end

    def self.of_project(project)
      sources(project)
        .reduce([stdlib_registry, []]) { |acc, source| absorb(acc, project, source) }
        .then do |(registry, skipped)|
          new(registry:, source_root: project.source_root, skipped:)
        end
    end

    # A module that won't compile is named rather than dropped: an absent
    # module reads as "that function doesn't exist".
    def self.absorb((registry, skipped), project, (root, uri))
      case load_module(project, root, uri)
      in nil then [registry, skipped + [uri]]
      in loaded then [merge(registry, loaded), skipped]
      end
    end

    def self.load_module(project, root, uri)
      ModuleLoader.load(root, uri, cache_dir: project.cache_path, tolerant: true)
    rescue CompilationError
      nil
    end

    def self.merge(into, from)
      into.with(
        modules: into.modules.merge(from.modules),
        implementations: into.implementations.merge(from.implementations),
      )
    end

    def self.sources(project)
      [project.source_root, *Jade.extensions]
        .uniq
        .flat_map { |root| jade_files(root).map { [root, it] } }
    end

    def self.jade_files(root)
      Dir
        .glob(File.join(root, '**', '*.jd'))
        .map { Pathname.new(it).relative_path_from(root).to_s }
        .sort
    end

    private_class_method :of_project, :absorb, :load_module, :merge, :sources, :jade_files

    ORIGIN_ORDER = { 'project' => 0, 'extension' => 1, 'stdlib' => 2 }.freeze

    KIND_ORDER = {
      'type' => 0,
      'struct' => 0,
      'alias' => 0,
      'interface' => 1,
      'constructor' => 2,
      'function' => 3,
    }.freeze

    def modules
      registry
        .modules
        .map { |name, entry| { name:, origin: origin(entry) } }
        .sort_by { [ORIGIN_ORDER.fetch(it[:origin]), it[:name]] }
    end

    def describe(module_name)
      registry
        .modules[module_name]
        &.then do
          {
            module: module_name,
            origin: origin(it),
            symbols: entries_for(module_name, it),
          }
        end
    end

    def lookup(qualified_name)
      *module_parts, name = qualified_name.split('.')
      module_parts
        .join('.')
        .then { describe(it) }
        &.fetch(:symbols)
        &.find { it[:name] == name }
    end

    def search(term)
      registry
        .modules
        .flat_map { |name, entry| entries_for(name, entry) }
        .select { it[:qualified_name].downcase.include?(term.downcase) }
    end

    private

    # `Source#root` is nil for the stdlib, which never comes off disk.
    def origin(entry)
      case entry.source&.root
      in nil then 'stdlib'
      in ^(source_root) then 'project'
      else 'extension'
      end
    end

    def entries_for(module_name, entry)
      entry
        .exposes
        .uniq { [it.class, it.name] }
        .filter_map { symbol_for(entry, it) }
        .map { entry_for(module_name, it) }
        .reject { Stdlib.private_constructor?(it[:qualified_name]) }
        .sort_by { [KIND_ORDER.fetch(it[:kind], 9), it[:name]] }
    end

    def symbol_for(entry, ref)
      ref.is_a?(Symbol::TypeRef) ?
        entry.defined_types[ref.name] :
        entry.defined_values[ref.name]
    end

    def entry_for(module_name, symbol)
      "#{module_name}.#{symbol.name}".then do |qualified_name|
        {
          name: symbol.name,
          qualified_name:,
          kind: kind_of(symbol),
          signature: render(symbol, qualified_name),
          **extras(symbol),
        }
      end
    end

    def kind_of(symbol)
      case symbol
      in Symbol::Union then 'type'
      in Symbol::Struct then 'struct'
      in Symbol::Alias then 'alias'
      in Symbol::Interface then 'interface'
      in Symbol::Constructor | Symbol::Variant then 'constructor'
      else 'function'
      end
    end

    def render(symbol, qualified_name)
      case symbol
      in Symbol::Union
        "type #{symbol.name}#{type_params(symbol.type_params)}"

      in Symbol::Struct
        "struct #{symbol.name}#{type_params(symbol.type_params)}#{fields(symbol)}"

      in Symbol::Alias
        "type alias #{symbol.name}#{type_params(symbol.type_params)} = #{body(symbol)}"

      in Symbol::Interface
        "interface #{symbol.name}(#{symbol.type_param.name})"

      else
        declared(symbol)
          .then { |(type, cs)| Signature.render(qualified_name, nullary(type), cs) }
      end
    end

    # The declared annotation, never the module env's scheme: the env collapses
    # distinct type variables on stdlib functions backing an interface, so
    # `Result.map` reads there as `(a) -> a` — unable to change the element
    # type, which it can.
    def declared(symbol)
      Type.from_symbol(symbol, registry, Frontend::TypeChecking::VarGen.new)
    end

    # `Dict.empty()` is a compile error — it's a value, not a nullary call.
    def nullary(type)
      case type
      in Type::Function(args: [], return_type:) then return_type
      else type
      end
    end

    def body(symbol)
      declared(symbol.body).then { |(type, _)| type }
    end

    def fields(symbol)
      return '' unless symbol.record_type

      declared(symbol.record_type)
        .then { |(type, _)| " = #{type}" }
    end

    def type_params(params)
      return '' if params.nil? || params.empty?

      params
        .map { it.respond_to?(:name) ? it.name : it.to_s }
        .join(', ')
        .then { "(#{it})" }
    end

    def extras(symbol)
      case symbol
      in Symbol::Union
        { implements: implements(symbol), variants: symbol.constructor_refs.map(&:name) }

      in Symbol::Struct
        { implements: implements(symbol) }

      in Symbol::Interface
        { implemented_by: implemented_by(symbol) }

      else
        {}
      end
    end

    def implements(type_symbol)
      instances { it[1] == type_symbol.qualified_name }.map { it[0] }
    end

    def implemented_by(interface_symbol)
      instances { it[0] == interface_symbol.qualified_name }.map { it[1] }
    end

    def instances(&)
      registry
        .implementations
        .keys
        .select(&)
        .uniq
        .sort
    end
  end
end
