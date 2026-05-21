require 'jade'

Jade.register_extension(File.expand_path('jade-sql', __dir__))

require_relative 'jade-sql/uuid_runtime'

# Encoded `Sql.Run.SqlError` values (the `[tag, ...args]` shape produced
# by Jade's variant encoder). Used by `runtime.rb` to emit errors back
# across the port boundary, and by anyone stubbing the ports in tests.
module JadeSql
  module SqlErrors
    NOT_FOUND  = ["NotFound"].freeze
    NOT_UNIQUE = ["NotUnique"].freeze

    def self.db_error(msg) = ["DbError", msg]
    def self.not_found     = NOT_FOUND
    def self.not_unique    = NOT_UNIQUE
  end
end

module Sql
  module Run
    module Errors
      class Error < StandardError; end
      class DbError   < Error; end
      class NotFound  < Error; end
      class NotUnique < Error; end

      BY_TAG = {
        "DbError"   => DbError,
        "NotFound"  => NotFound,
        "NotUnique" => NotUnique,
      }.freeze
    end

    def self.raise_typed!(encoded)
      type, message = encoded
      klass = Errors::BY_TAG.fetch(type, Errors::Error)
      raise klass, message
    end
  end
end
