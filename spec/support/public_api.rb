require 'jade'
require 'jade/api'

module Jade
  # Every name a program can depend on, with the shape it depends on.
  # Snapshotted so a change to one is a line in a diff rather than
  # something a user finds out about at their own compile.
  module PublicApi
    extend self

    SNAPSHOT = File.expand_path('../fixtures/public_api.txt', __dir__)

    def snapshot
      Api
        .stdlib
        .then { |api| api.modules.flat_map { symbols(api, it[:name]) } }
        .then { (it + interfaces).sort.join("\n") + "\n" }
    end

    def committed
      File.exist?(SNAPSHOT) ? File.read(SNAPSHOT) : ''
    end

    def write!
      File.write(SNAPSHOT, snapshot)
    end

    def diff
      (committed.lines - snapshot.lines).map { "- #{it}" }
        .then { it + (snapshot.lines - committed.lines).map { "+ #{it}" } }
        .join
    end

    private

    def symbols(api, module_name)
      api
        .describe(module_name)[:symbols]
        .map { it[:signature] }
    end

    # An implementation of an interface has to satisfy every member, so a
    # member added anywhere breaks every implementation everywhere.
    def interfaces
      Api
        .stdlib_registry
        .modules
        .each_value
        .flat_map { |entry| entry.defined_types.values }
        .grep(Symbol::Interface)
        .map { "#{it.module_name}.#{it.name} members: #{it.functions.map(&:name).sort.join(', ')}" }
    end
  end
end
