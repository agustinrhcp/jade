require 'set'

require 'jade/symbol'
require 'jade/frontend/usage_analysis/reference_index'
require 'jade/module_loader/topological_sort'

module Jade
  # Which effect atoms — ports and effectful intrinsics — each function can
  # reach through the call graph.
  #
  # Runs over the whole registry rather than per module, because effects
  # propagate upward: editing a leaf changes its callers' reach without
  # touching their source, so a per-module answer would go stale.
  #
  # Naming a function is enough to be charged for it, which is why
  # `:as_value` propagates as well as `:called`. `List.map(xs, insert)`
  # charges the caller and not `List.map` — that is what lets higher-order
  # code work without effect polymorphism in the type system, and it
  # attributes the effect to the module whose source summons it.
  #
  # Interface dispatch fans out to every implementation of the function
  # rather than the one the call site resolves to. The dictionary that pins
  # it down lives on the AST node, not on a Reference, so this
  # over-approximates — in the safe direction.
  module Capabilities
    extend self

    PROPAGATING = ::Set[:called, :as_value].freeze

    Atom = Data.define(:kind, :module_name, :name, :host) do
      def to_s
        case kind
        in :port then "#{host}.#{name}"
        in :intrinsic then "#{module_name}.#{name}"
        end
      end
    end

    # `atoms` maps each reachable atom to the shortest path of intermediate
    # functions leading to it, which is what makes a reported effect
    # actionable rather than a puzzle. `complete` is false when a reference
    # along the way could not be resolved: the set is then a lower bound,
    # and no caller may read it as the whole story.
    Reach = Data.define(:atoms, :complete) do
      def self.pure
        new(atoms: {}, complete: true)
      end

      def pure?
        atoms.empty? && complete
      end

      def names
        atoms.keys.map(&:to_s).sort
      end

      def path_to(atom)
        atoms[atom]
      end
    end

    Node = Data.define(:atoms, :edges, :complete)

    def analyze(registry)
      dependencies_first(registry)
        .flat_map { nodes_for(it, registry) }
        .to_h
        .then { settle(it, seed(it)) }
    end

    # An atom is its own reach: it never appears as a graph node, since it
    # has no Jade body to walk.
    def for(registry, symbol)
      atom(symbol)
        .then { it ? Reach[{ it => [] }, true] : analyze(registry).fetch(key_for(symbol), Reach.pure) }
    end

    def atoms(registry)
      registry
        .modules
        .each_value
        .flat_map { it.defined_values.each_value.filter_map { |sym| atom(sym) } }
        .sort_by(&:to_s)
    end

    private

    def key_for(symbol)
      Frontend::UsageAnalysis::ReferenceIndex.key_for(symbol)
    end

    # Settling a callee before its callers lets one pass carry an atom the
    # whole way up. Without it the number of rounds tracks how unlucky the
    # hash order was, which on a deep call chain is an order of magnitude.
    # Stdlib modules are absent from the graph and sort first: nothing they
    # define depends on app code.
    def dependencies_first(registry)
      ModuleLoader::TopologicalSort
        .sort(registry.dependency_graph)
        .each_with_index
        .to_h
        .then { |rank| registry.modules.each_value.sort_by.with_index { |e, i| [rank.fetch(e.name, -1), i] } }
    end

    def nodes_for(entry, registry)
      by_owner = references_by_owner(entry)

      entry
        .defined_values
        .each_value
        .select { it.is_a?(Symbol::Function) }
        .map { key_for(it) }
        .map { [it, node(by_owner.fetch(it, []), registry, entry.usage_index.nil?)] }
    end

    def references_by_owner(entry)
      return {} unless entry.usage_index

      entry
        .usage_index
        .references
        .each_value
        .flat_map { it }
        .select { PROPAGATING.include?(it.kind) && it.owner }
        .group_by(&:owner)
    end

    # `blind` is a module holding Jade functions that was never walked, so
    # its edges are unknown rather than absent — the one case where an
    # empty node must not read as pure.
    def node(references, registry, blind)
      references
        .flat_map { contributions(it.symbol_key, registry) }
        .then { build(it, blind) }
    end

    def build(found, blind)
      Node[
        found.filter_map { |kind, value| value if kind == :atom }.to_set,
        found.filter_map { |kind, value| value if kind == :edge }.to_set,
        !blind && found.none? { |kind, _| kind == :unknown },
      ]
    end

    def contributions(key, registry)
      return [] unless key.first.is_a?(String)

      case resolve(key, registry)
      in Symbol::InteropFunction | Symbol::StdlibFunction => sym
        atom(sym).then { it ? [[:atom, it]] : [] }

      in Symbol::Function
        [[:edge, key]]

      in Symbol::InterfaceFunction => sym
        dispatch(sym, registry)

      in nil
        [[:unknown, key]]

      else
        []
      end
    end

    def dispatch(symbol, registry)
      registry
        .implementations
        .each_value
        .select { it.interface.qname == symbol.interface.qname }
        .filter_map { it.functions[symbol.name] }
        .map { [:edge, key_for(it)] }
    end

    def resolve(key, registry)
      registry
        .get(key.first)
        &.defined_values
        &.[](key.last)
    end

    def atom(symbol)
      case symbol
      in Symbol::InteropFunction(module_name:, name:, interop_module_name:)
        Atom[:port, module_name, name, interop_module_name]

      in Symbol::StdlibFunction(module_name:, name:, effect: String)
        Atom[:intrinsic, module_name, name, nil]

      else
        nil
      end
    end

    def seed(nodes)
      nodes.to_h { |key, node| [key, Reach[node.atoms.to_h { [it, []] }, node.complete]] }
    end

    def settle(nodes, reach)
      loop do
        break reach if nodes.count { |key, node| absorb(reach, key, node) }.zero?
      end
    end

    def absorb(reach, key, node)
      node
        .edges
        .select { reach.key?(it) }
        .reduce(reach[key]) { |acc, callee| merge(acc, reach[callee], callee) }
        .then { it == reach[key] ? false : !!(reach[key] = it) }
    end

    def merge(into, from, callee)
      Reach[
        into.atoms.merge(shortened(into, from, callee)),
        into.complete && from.complete,
      ]
    end

    def shortened(into, from, callee)
      from
        .atoms
        .reject { |atom, path| already_shorter?(into.atoms[atom], path) }
        .transform_values { [callee] + it }
    end

    def already_shorter?(existing, path)
      existing && existing.size <= path.size + 1
    end
  end
end
