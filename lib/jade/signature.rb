module Jade
  # One-line rendering of a name and its type, shared by hover and `q api`.
  module Signature
    extend self

    def render(name, type, constraints)
      "#{name} : #{constraint_prefix(constraints)}#{type}"
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
