require 'jade/stdlib/intrinsics'

module Jade
  module Stdlib
    # `non_zero` cannot live in Basics beside the `NonZero` type it builds,
    # because its `Maybe` comes from a module that needs Basics first.
    module Number
      extend Intrinsics

      import Basics

      # What counts as zero is the type's business, so this dispatches
      # rather than asking Ruby whether the value is `0`.
      function(
        :non_zero,
        { n: 'a' },
        'Maybe(NonZero(a))',
        constraints: [['Basics.Numeric', 'a'], ['Basics.Eq', 'a']],
        body: Symbol::DerivedFunction.new(
          params: ['n'],
          body: [:call,
            [:stdlib_fn, 'Number.checked'],
            [
              [:var, 'n'],
              [:call, [:impl_arg, 0, 'from_int'], [0]],
              [:impl_arg, 1, '(==)'],
            ]],
        ),
      )

      # For anyone implementing `Numeric` themselves: the divisor arrives
      # wrapped and the arithmetic needs it bare.
      function(:unwrap, { n: 'NonZero(a)' }, 'a')

      function(
        :checked,
        { n: 'a', zero: 'a', eq: 'a, a -> Bool' },
        'Maybe(NonZero(a))',
        private: true,
      ) do |n, zero, eq|
        eq.call(n, zero) ? Jade::Maybe::Nothing[] : Jade::Maybe::Just[n]
      end

      default_importing(['non_zero'])
    end
  end
end
