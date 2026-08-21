module Jade
  # Where an extension gem hooks into compilation. Only gems named in ALLOWED
  # may register, so jade knows who extends it and nothing about what they do.
  module Extensions
    extend self

    ALLOWED = %w[jade-sql].freeze
    PHASES = %i[call].freeze

    class NotAllowed < StandardError
      def initialize(gem_name)
        super(
          "#{gem_name} may not extend the compiler; " \
            "allowed: #{ALLOWED.join(', ')}"
        )
      end
    end

    class UnknownPhase < StandardError
      def initialize(phase)
        super("no such check phase #{phase.inspect}; known: #{PHASES.join(', ')}")
      end
    end

    def register_deriver(gem_name, deriver)
      allow!(gem_name)
      @derivers = derivers | [deriver]
    end

    # A `:call` check answers `watches -> [qualified name]` and
    # `check(context) -> [error]`. Watching by name keeps every other call in
    # the program off the check's path entirely.
    def register_check(gem_name, phase, check)
      allow!(gem_name)
      fail UnknownPhase.new(phase) unless PHASES.include?(phase)

      @call_checks = check
        .watches
        .reduce(call_checks) { |acc, name| acc.merge(name => acc.fetch(name, []) | [check]) }
    end

    def derivers = @derivers ||= []

    def call_checks = @call_checks ||= {}

    # The node travels with the types because a literal's value — a SQL string,
    # a constant predicate — is not in them.
    CallContext = Data.define(:name, :arg_types, :node, :registry, :entry_name, :span)

    def check_call(name, arg_types, node, registry, entry_name, span)
      call_checks[name].then do |watching|
        next [] if watching.nil?

        CallContext[name, arg_types, node, registry, entry_name, span]
          .then { |ctx| watching.flat_map { it.check(ctx) } }
      end
    end

    def reset!
      @derivers = []
      @call_checks = {}
    end

    private

    def allow!(gem_name)
      fail NotAllowed.new(gem_name) unless ALLOWED.include?(gem_name)
    end
  end
end
