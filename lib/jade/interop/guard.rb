require 'jade/interop/guard/error'

module Jade
  module Interop
    module Guard
      extend self

      def guard(ruby_value, jades_expected)
        case [ruby_value, jades_expected]
        in [Jade::Task, ['task', ok_type, err_type]]
          Jade::Task[-> do
            case ruby_value.run
            in ::Result::Ok[val] then ::Result::Ok[guard(val, ok_type)]
            in ::Result::Err[err] then ::Result::Err[guard(err, err_type)]
            end
          end]

        in [_, ['task', _, _]]
          fail Error.new(:wrong_type, 'Jade::Task', ruby_value)

        in [_, 'decode_value']
          ::Decode::Value[ruby_value]

        in [_, 'never']
          ruby_value

        in [Integer, 'int']
          ruby_value

        in [Float, 'float']
          ruby_value

        in [String, 'string']
          ruby_value.dup

        in [TrueClass | FalseClass, :bool]
          ruby_value

        in [nil, ['maybe', _]] 
          Maybe::Nothing[]

        in [nil, _]
          fail Error.new(:nil_value, jades_expected, nil)

        in [_, ['maybe', expected]]
          Maybe::Just[guard(ruby_value, expected)]

        in [Array, ['list', expected]]
          ruby_value
            .each_with_index.map do |element, index|
              begin
                guard(element, expected)
              rescue Error
                fail Error.new(:invalid_list_element, expected, element, index)
              end
            end
            .dup

        in [Data, Hash]
          guard(ruby_value.to_h, jades_expected)

        in [Hash, Hash]
          jades_expected
            .reduce({}) do |acc, (k, expected)|
              r_val = (ruby_value[k] || ruby_value[k.to_sym] || fail(Error.new(:missing_key, k, ruby_value)))
              acc.merge(k => guard(r_val, expected) )
            end
            .then { Data.define(*it.keys).new(**it) }
        else
          fail Error.new(:wrong_type, jades_expected, ruby_value)
        end
      end
    end
  end
end
