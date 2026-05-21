require 'securerandom'
require 'jade/port'

# UUID v4/v7 generation ports for Sql.Uuid. Stdlib-only, no AR — safe
# to require eagerly from jade-sql.rb (unlike runtime.rb which pulls
# in ActiveRecord and is opt-in).
module JadeSql
  module Uuid
    module Runtime
      extend Jade::Port

      task(:generate_v4) { |t| t.ok({ "value" => ::SecureRandom.uuid }) }
      task(:generate_v7) { |t| t.ok({ "value" => ::SecureRandom.uuid_v7 }) }
    end
  end
end
