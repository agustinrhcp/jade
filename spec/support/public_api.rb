require 'json'

require 'jade'
require 'jade/api'

module Jade
  module PublicApi
    extend self

    SNAPSHOT = File.expand_path('../fixtures/public_api.json', __dir__)

    def snapshot
      Api.stdlib.surface.then { JSON.pretty_generate(it) + "\n" }
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
  end
end
