module Jade
  module Frontend
    module TypeChecking
      module Error
        class UnreachableBranch < Jade::Error
          def initialize(entry, span)
            super(entry:, span:)
          end

          def message
            'This branch can never match. The branches above it already cover ' \
              'every value that would reach it.'
          end

          def label
            'unreachable branch'
          end
        end
      end
    end
  end
end
