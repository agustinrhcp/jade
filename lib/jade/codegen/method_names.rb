module Jade
  module Codegen
    module MethodNames
      extend self

      INTERFACE_METHODS = {
        'Basics.Eq' => {
          '(==)' => '==',
        },
        'Basics.Comparable' => {
          'compare' => 'compare',
        },
        'Basics.Numeric' => {
          '(+)' => '+',
          '(-)' => '-',
          '(*)' => '*',
          '(/)' => '/',
        },
        'Basics.Appendable' => {
          '(++)' => '+',
        },
      }.freeze

      OPERATOR_INTERFACES = INTERFACE_METHODS.keys.to_set.freeze

      CALL_OPERATORS = {
        'Basics.(==)'    => '==',
        'Basics.(!=)'    => '!=',
        'Basics.(<)'     => '<',
        'Basics.(>)'     => '>',
        'Basics.(<=)'    => '<=',
        'Basics.(>=)'    => '>=',
        'Basics.(+)'     => '+',
        'Basics.(-)'     => '-',
        'Basics.(*)'     => '*',
        'Basics.(/)'     => '/',
        'Basics.(++)'    => '+',
        'Basics.compare' => 'compare',
      }.freeze

      def interface_method(interface_qname, fn_name)
        INTERFACE_METHODS.dig(interface_qname, fn_name)
      end

      def operator_interface?(interface_qname)
        OPERATOR_INTERFACES.include?(interface_qname)
      end

      def call_operator(qualified_name)
        CALL_OPERATORS[qualified_name]
      end
    end
  end
end
