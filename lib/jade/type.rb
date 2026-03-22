require 'jade/type/base'

require 'jade/type/constraint'
require 'jade/type/anonymous_record'
require 'jade/type/application'
require 'jade/type/constructor'
require 'jade/type/function'
require 'jade/type/unit'
require 'jade/type/var'

module Jade
  module Type
    extend self

    def from_symbol(symbol, registry, var_gen)
      from_symbol_r(symbol, registry, var_gen, {})
        .then { |type, constraints, _| [type, constraints] }
    end

    def var(id, name = nil)
      Var[id, name, false]
    end

    def unit
      Unit[]
    end

    def int
      constructor('Basics.Int').apply([])
    end

    def unit
      constructor('Basics.Unit').apply([])
    end

    def float
      constructor('Basics.Float').apply([])
    end

    def string
      constructor('String.String').apply([])
    end

    def bool
      constructor('Basics.Bool').apply([])
    end

    def list
      constructor('List.List')
    end

    def constructor(name)
      Constructor[name]
    end

    def function(args, return_type)
      Function[args, return_type]
    end

    def anonymous_record(fields, row_var)
      AnonymousRecord[fields, row_var]
    end

    def constraint(interface_id, type, span)
      Constraint[interface_id, type, span]
    end

    private

    def from_symbol_r(symbol, registry, var_gen, var_map)
      case symbol
      in Symbol::Variable(name:)
        if var_map[name]
          [var_map[name], [], var_map]
        else
          var_gen
            .next(name)
            .then { [it, [], var_map.merge(name => it)] }
        end

      in Symbol::TypeRef | Symbol::ValueRef
        registry
          .lookup(symbol)
          .then { from_symbol_r(it, registry, var_gen, var_map) }

      in Symbol::Union
        union_vars, union_cs, union_map = symbol
          .type_params
          .reduce([[], [], var_map]) do |(types, cs, local_map), sym|
            from_symbol_r(sym, registry, var_gen, local_map)
              .then { |(t, c, new_map)| [types + [t], cs + c, new_map] }
          end

        Type
          .constructor(symbol.qualified_name)
          .then { [it.apply(union_vars), union_cs, union_map] }

      in Symbol::Function | Symbol::StdlibFunction
        args, arg_cs, local_map = symbol
          .params
          .values
          .reduce([[], [], {}]) do |(types, cs, local_map), sym|
            from_symbol_r(sym, registry, var_gen, local_map)
              .then { |(t, c, new_map)| [types + [t], cs + c, new_map] }
          end

        from_symbol_r(symbol.return_type, registry, var_gen, local_map)
          .then { |(t, c, _)| [Type.function(args, t), c + arg_cs] }
          .then { it + [var_map] }

      in Symbol::FunctionType | Symbol::InteropFunction
        # Same as function and stdlib but without keyed params.
        args, arg_cs, local_map = symbol
          .params
          .reduce([[], [], {}]) do |(types, cs, local_map), sym|
            from_symbol_r(sym, registry, var_gen, local_map)
              .then { |(t, c, new_map)| [types + [t], cs + c, new_map] }
          end

        from_symbol_r(symbol.return_type, registry, var_gen, local_map)
          .then { |(t, c, _)| [Type.function(args, t), c] }
          .then { it + [var_map] }

      in Symbol::InterfaceFunction
        # Same as function and stdlib but without keyed params.
        args, arg_cs, local_map = symbol
          .params
          .reduce([[], [], {}]) do |(types, cs, local_map), sym|
            from_symbol_r(sym, registry, var_gen, local_map)
              .then { |(t, c, new_map)| [types + [t], cs + c, new_map] }
          end

        interface = registry.lookup(symbol.interface)
        constraint = Type
          .constraint(
            symbol.interface.qualified_name,
            from_symbol_r(interface.type_param, registry, var_gen, local_map).first,
            nil,
          )

        from_symbol_r(symbol.return_type, registry, var_gen, local_map)
          .then { |(t, c, _)| [Type.function(args, t), c + arg_cs + [constraint]] }
          .then { it + [var_map] }

      in Symbol::Constructor
        union_type, union_cs, union_vars =
          from_symbol_r(symbol.parent, registry, var_gen, var_map)

        args, arg_cs, args_map = symbol
          .args
          .reduce([[], [], union_vars]) do |(types, cs, local_map), sym|
            from_symbol_r(sym, registry, var_gen, local_map)
              .then { |(t, c, new_map)| [types + [t], cs + c, new_map] }
          end

        Type
          .function(
            args,
            union_type,
          )
          .then { [it, union_cs + arg_cs, args_map] }

      in Symbol::AnonymousRecord(fields:)
        fields
          .map { |k, _| [k, var_gen.next(k)] }.to_h
          .then { Type.anonymous_record(it, nil) }
          .then { [it, [], var_map] }

      in Symbol::Struct(record_type:)
        struct_vars, struct_cs, struct_map = symbol
          .type_params
          .reduce([[], [], var_map]) do |(types, cs, local_map), sym|
            from_symbol_r(sym, registry, var_gen, local_map)
              .then { |(t, c, new_map)| [types + [t], cs + c, new_map] }
          end

        Type
          .constructor(symbol.qualified_name)
          .then { [it.apply(struct_vars), struct_cs, struct_map] }

      in Symbol::RecordType(fields:, row_var:)
        row, _, row_map = row_var
          &.then { from_symbol_r(row_var, registry, var_gen, var_map) } ||
          [nil, [], var_map]

        fields
          .reduce([{}, [], row_map]) do |(type, cs, local_map), (k, v)|
            from_symbol_r(v, registry, var_gen, local_map)
              .then { |(t, c, new_map)| [type.merge(k => t), c + cs, new_map] }
          end
          .then { |t, cs, map| [Type.anonymous_record(t, row), cs, map] }

      in Symbol::TypeApplication(constructor:, args:)
        union_type, union_cs, union_vars =
          from_symbol_r(constructor, registry, var_gen, var_map)

        args, args_cs, args_map = symbol
          .args
          .reduce([[], [], union_vars]) do |(types, cs, local_map), sym|
            from_symbol_r(sym, registry, var_gen, local_map)
              .then { |(t, c, new_map)| [types + [t], cs + c, new_map] }
          end

        Type
          .constructor(symbol.constructor.qualified_name)
          .then { [it.apply(args), union_cs + args_cs, args_map] }
      end
    end
  end
end
