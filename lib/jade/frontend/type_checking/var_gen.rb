module Jade
  module Frontend
    module TypeChecking
      class VarGen
        def initialize
          @next_id = 1
        end

        def fresh_id
          "t#{@next_id}"
            .tap { @next_id += 1 }
        end

        def fresh(name = nil)
          fresh_id
            .then { Type.var(it, name) }
        end

        def next(name)
          "#{name}#{@next_id}"
            .tap { @next_id += 1 }
            .then { Type.var(it, name) }
        end
      end
    end
  end
end
