module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class NoBaseCase < Jade::Error
          HELP = {
            'struct' => 'wrap the field in something that has an empty case: ' \
                        '`Maybe(%<name>s)` can be `Nothing`, `List(%<name>s)` can be empty',
            'type' => 'add a variant that does not mention `%<name>s`, ' \
                      'the way `Nothing` does for `Maybe`',
          }.freeze

          def initialize(entry, span, name:, kind:)
            @name = name
            @kind = kind
            super(entry:, span:)
          end

          def message
            "`#{@name}` can never be built: every `#{@name}` needs a `#{@name}` " \
              'inside it first'
          end

          def label
            'nothing here stops the recursion'
          end

          def notes
            [
              Jade::Diagnostics::Annotation[
                :note,
                "a type may refer to itself; `#{@name}` just has no case that " \
                  "stops, so there is no smallest `#{@name}` to start from",
              ],
              Jade::Diagnostics::Annotation[
                :help,
                format(HELP.fetch(@kind), name: @name),
              ],
            ]
          end
        end
      end
    end
  end
end
