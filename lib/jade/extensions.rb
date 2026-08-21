module Jade
  # Where an extension gem hooks into compilation. Only gems named in ALLOWED
  # may register, so jade knows who extends it and nothing about what they do.
  module Extensions
    extend self

    ALLOWED = %w[jade-sql].freeze

    class NotAllowed < StandardError
      def initialize(gem_name)
        super(
          "#{gem_name} may not extend the compiler; " \
            "allowed: #{ALLOWED.join(', ')}"
        )
      end
    end

    def register_deriver(gem_name, deriver)
      allow!(gem_name)
      derivers << deriver unless derivers.include?(deriver)
    end

    PHASES = %i[call].freeze

    class UnknownPhase < StandardError
      def initialize(phase)
        super("no such check phase #{phase.inspect}; known: #{PHASES.join(', ')}")
      end
    end

    # `check(context) -> [error]`. The node travels with the types because a
    # literal's value — a SQL string, a constant predicate — is not in them.
    def register_check(gem_name, phase, check)
      allow!(gem_name)
      fail UnknownPhase.new(phase) unless PHASES.include?(phase)

      (checks[phase] ||= []) << check unless checks[phase]&.include?(check)
    end

    def derivers = @derivers ||= []

    def checks = @checks ||= {}

    CallContext = Data.define(:name, :arg_types, :node, :registry, :entry_name, :span)

    def check_call(name, arg_types, node, registry, entry_name, span)
      registered = checks[:call]
      return [] if registered.nil? || registered.empty? || name.nil?

      CallContext[name, arg_types, node, registry, entry_name, span]
        .then { |ctx| registered.flat_map { it.check(ctx) } }
    end

    def reset!
      @derivers = []
      @checks = {}
    end

    private

    def allow!(gem_name)
      fail NotAllowed.new(gem_name) unless ALLOWED.include?(gem_name)
    end
  end
end
