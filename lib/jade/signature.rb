require 'jade/frontend/type_checking/substitution'

module Jade
  # One-line rendering of a name and its type, shared by hover and `q api`.
  module Signature
    extend self

    LETTERS = ('a'..'z').to_a.freeze

    def render(name, type, constraints)
      naming(type, constraints)
        .then { |sub| [sub.apply(type), constraints.map { sub.apply(it) }] }
        .then { |(renamed, cs)| "#{name} : #{constraint_prefix(cs)}#{renamed}" }
    end

    # Vars compare by id but print as their name, which nothing keeps unique.
    def naming(type, constraints)
      (type.unbound_vars + constraints.flat_map(&:unbound_vars))
        .uniq(&:id)
        .reduce([{}, []]) do |(mappings, taken), var|
          display_name(var, taken)
            .then { [mappings.merge(var.id => Type.var(var.id, it)), taken + [it]] }
        end
        .then { |(mappings, _)| Frontend::TypeChecking::Substitution[mappings] }
    end

    def display_name(var, taken)
      return var.name if var.name && !taken.include?(var.name)

      (LETTERS - taken).first || "#{var.name}#{taken.size}"
    end

    def constraint_prefix(constraints)
      return '' if constraints.empty?

      constraints
        .map { short_constraint(it) }
        .uniq
        .join(', ')
        .then { "#{it} => " }
    end

    def short_constraint(constraint)
      "#{constraint.interface.split('.').last} #{constraint.type}"
    end
  end
end
